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

static void print_menu(UINTN selected, UINTN seconds_left) {
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY | EFI_BACKGROUND_BLACK);
    Print(L"  CarsonBoot\r\n\r\n");

    if (selected == 0)
        ST->ConOut->SetAttribute(ST->ConOut, EFI_WHITE | EFI_BACKGROUND_BLUE);
    Print(L"  > Boot CarsonLinux\r\n");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY | EFI_BACKGROUND_BLACK);

    if (selected == 1)
        ST->ConOut->SetAttribute(ST->ConOut, EFI_WHITE | EFI_BACKGROUND_BLUE);
    Print(L"    Reboot to firmware\r\n");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY | EFI_BACKGROUND_BLACK);

    Print(L"\r\n  Up/Down: select    Enter: boot\r\n");
    Print(L"  Auto-boot in %u seconds...\r\n", seconds_left);
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

static EFI_STATUS boot_menu(void) {
    EFI_INPUT_KEY key;
    EFI_EVENT timer_event;
    EFI_EVENT events[2];
    EFI_STATUS status;
    UINTN index;
    UINTN selected = 0;
    UINTN seconds_left = 5;

    status = uefi_call_wrapper(BS->CreateEvent, 5, EVT_TIMER, TPL_CALLBACK,
                               NULL, NULL, NULL, &timer_event);
    if (EFI_ERROR(status))
        return status;

    status = uefi_call_wrapper(BS->SetTimer, 3, timer_event, TimerPeriodic,
                               10000000);
    if (EFI_ERROR(status)) {
        uefi_call_wrapper(BS->CloseEvent, 1, timer_event);
        return status;
    }

    events[0] = ST->ConIn->WaitForKey;
    events[1] = timer_event;

    ST->ConOut->ClearScreen(ST->ConOut);
    print_banner();
    print_menu(selected, seconds_left);

    while (seconds_left > 0) {
        status = uefi_call_wrapper(BS->WaitForEvent, 3, 2, events, &index);
        if (EFI_ERROR(status))
            break;

        if (index == 0) {
            status = uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2,
                                       ST->ConIn, &key);
            if (EFI_ERROR(status))
                continue;

            if (key.ScanCode == SCAN_UP) {
                selected = 0;
            } else if (key.ScanCode == SCAN_DOWN) {
                selected = 1;
            } else if (key.UnicodeChar == CHAR_CARRIAGE_RETURN) {
                break;
            } else {
                continue;
            }

            ST->ConOut->ClearScreen(ST->ConOut);
            print_banner();
            print_menu(selected, seconds_left);
        } else {
            if (seconds_left > 0)
                seconds_left--;

            ST->ConOut->ClearScreen(ST->ConOut);
            print_banner();

            if (seconds_left == 0) {
                selected = 0;
                Print(L"  Auto-booting CarsonLinux...\r\n\r\n");
                break;
            }

            print_menu(selected, seconds_left);
        }
    }

    uefi_call_wrapper(BS->SetTimer, 3, timer_event, TimerCancel, 0);
    uefi_call_wrapper(BS->CloseEvent, 1, timer_event);

    if (selected == 1) {
        Print(L"\r\n  Rebooting to firmware...\r\n");
        uefi_call_wrapper(RT->ResetSystem, 4, EfiResetWarm,
                           EFI_SUCCESS, 0, NULL);
        return EFI_SUCCESS;
    }

    return launch_grub();
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *system_table) {
    EFI_STATUS status;

    carsonboot_image = image;
    ST = system_table;
    BS = ST->BootServices;

    InitializeLib(image, ST);
    ST->ConOut->ClearScreen(ST->ConOut);
    print_banner();

    status = boot_menu();

    if (EFI_ERROR(status)) {
        ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTRED | EFI_BACKGROUND_BLACK);
        Print(L"  [!] CarsonBoot failed to start the boot path.\r\n");
        Print(L"  Status: %r\r\n", status);
        ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY | EFI_BACKGROUND_BLACK);
        Print(L"\r\n  Press any key to return to firmware.\r\n");
        WaitForSingleEvent(ST->ConIn->WaitForKey, 0);
    }

    return status;
}
