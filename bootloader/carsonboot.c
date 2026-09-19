#include <efi.h>
#include <efilib.h>

static EFI_HANDLE carsonboot_image;

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

static EFI_STATUS launch_grub(void) {
    EFI_LOADED_IMAGE *loaded;
    EFI_HANDLE image;
    EFI_DEVICE_PATH *device_path;
    EFI_STATUS status;
    CHAR16 path[] = L"\\EFI\\BOOT\\GRUBX64.EFI";

    status = uefi_call_wrapper(BS->HandleProtocol, 3, carsonboot_image,
                               &LoadedImageProtocol, (void **)&loaded);
    if (EFI_ERROR(status)) return status;

    device_path = FileDevicePath(loaded->DeviceHandle, path);
    if (device_path == NULL) return EFI_OUT_OF_RESOURCES;

    status = uefi_call_wrapper(BS->LoadImage, 6, FALSE, carsonboot_image,
                               device_path, NULL, 0, &image);

    FreePool(device_path);
    if (EFI_ERROR(status)) {
        Print(L"\r\n[CarsonBoot] Could not load GRUB: %r\r\n", status);
        return status;
    }

    return uefi_call_wrapper(BS->StartImage, 3, image, NULL, NULL);
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *system_table) {
    EFI_STATUS status;
    carsonboot_image = image;
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
