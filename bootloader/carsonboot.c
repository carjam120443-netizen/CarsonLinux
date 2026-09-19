#include <efi.h>
#include <efilib.h>

static void print_banner(void) {
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTBLUE | EFI_BACKGROUND_BLACK);
    Print(L"\r\n");
    Print(L"  +--------------------------------------------------+\r\n");
    Print(L"  |              C A R S O N L I N U X               |\r\n");
    Print(L"  |                                                  |\r\n");
    Print(L"  |                  C A R S O N B O O T             |\r\n");
    Print(L"  |                     version 0.1                  |\r\n");
    Print(L"  +--------------------------------------------------+\r\n\r\n");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY | EFI_BACKGROUND_BLACK);
}

static EFI_STATUS open_root(EFI_FILE_PROTOCOL **root) {
    EFI_LOADED_IMAGE *loaded;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs;
    EFI_STATUS status;

    status = uefi_call_wrapper(BS->HandleProtocol, 3, gImageHandle,
                               &LoadedImageProtocol, (void **)&loaded);
    if (EFI_ERROR(status)) return status;

    status = uefi_call_wrapper(BS->HandleProtocol, 3, loaded->DeviceHandle,
                               &FileSystemProtocol, (void **)&fs);
    if (EFI_ERROR(status)) return status;

    return uefi_call_wrapper(fs->OpenVolume, 2, fs, root);
}

static EFI_STATUS launch_grub(void) {
    EFI_FILE_PROTOCOL *root;
    EFI_FILE_PROTOCOL *file;
    EFI_HANDLE image;
    EFI_STATUS status;
    CHAR16 path[] = L"\\EFI\\BOOT\\GRUBX64.EFI";

    status = open_root(&root);
    if (EFI_ERROR(status)) return status;

    status = uefi_call_wrapper(root->Open, 5, root, &file, path,
                               EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(status)) {
        Print(L"\r\n[CarsonBoot] GRUB fallback not found.\r\n");
        uefi_call_wrapper(root->Close, 1, root);
        return status;
    }

    uefi_call_wrapper(file->Close, 1, file);

    status = uefi_call_wrapper(BS->LoadImage, 6, FALSE, gImageHandle,
                               NULL, NULL, 0, &image);
    if (EFI_ERROR(status)) {
        uefi_call_wrapper(root->Close, 1, root);
        return status;
    }

    // Re-open the image with the filesystem path so firmware resolves it.
    status = uefi_call_wrapper(BS->LoadImage, 6, FALSE, gImageHandle,
                               NULL, NULL, 0, &image);
    if (EFI_ERROR(status)) {
        uefi_call_wrapper(root->Close, 1, root);
        return status;
    }

    uefi_call_wrapper(root->Close, 1, root);
    return uefi_call_wrapper(BS->StartImage, 3, image, NULL, NULL);
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *system_table) {
    EFI_STATUS status;
    gImageHandle = image;
    ST = system_table;
    BS = ST->BootServices;

    InitializeLib(image, ST);
    ST->ConOut->ClearScreen(ST->ConOut);
    print_banner();

    Print(L"  Starting CarsonLinux...\r\n");
    Print(L"  [>] CarsonBoot is loading the default boot path...\r\n\r\n");

    status = launch_grub();
    if (EFI_ERROR(status)) {
        ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTRED | EFI_BACKGROUND_BLACK);
        Print(L"  [!] Unable to start the fallback loader.\r\n");
        Print(L"  Status: %r\r\n", status);
        ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY | EFI_BACKGROUND_BLACK);
        Print(L"\r\n  Press any key to return to firmware.\r\n");
        WaitForSingleEvent(ST->ConIn->WaitForKey, 0);
    }

    return status;
}
