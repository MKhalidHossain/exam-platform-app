# AGENTS.md

## Project Goal

This project has an authentication system with device locking. One user account should be allowed to log in only from one active device/installation at a time.

Current issue:
When a user installs the app and logs in, the backend stores the device installation ID. If the user uninstalls and reinstalls the app on the same phone, the app generates a new installation ID. The backend sees this as a different device and blocks login with a message like:

"Login Blocked. This account is already locked to another installation."

We need to fix this by adding a safe device re-link / reset flow.

## Required Behavior

The login flow should work like this:

1. User logs in with normal credentials.
2. App sends the current device installation ID with the login request.
3. Backend checks the saved device for that user.

Expected cases:

### Case 1: No device is registered
- Register the current device ID.
- Allow login.

### Case 2: Device ID matches registered device
- Allow login.

### Case 3: Device ID does not match
- Do not permanently block the user.
- Return a clear `DEVICE_MISMATCH` response.
- App should show a message and a button to verify/re-link the device.

## Device Mismatch Response

The backend should return a structured response like:

```json
{
  "success": false,
  "code": "DEVICE_MISMATCH",
  "message": "This account is already linked to another installation.",
  "can_request_device_reset": true
}