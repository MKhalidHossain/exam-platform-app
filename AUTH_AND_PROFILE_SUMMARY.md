# Auth Section & Profile Screen Summary

## Authentication Section

### Auth Screens:
1. **Splash Screen** (`splash_screen.dart`)
   - Initial screen when app launches
   - Route: `/splash`

2. **Onboarding Screen** (`onboarding_screen.dart`)
   - 4-page onboarding flow
   - Route: `/onboarding`

3. **Login Screen** (`login_screen.dart`)
   - Email and password login
   - Forgot password link
   - Sign up link
   - Route: `/login`

4. **Sign Up Screen** (`sign_up_screen.dart`)
   - Registration form (name, email, phone, password)
   - Terms & Conditions checkbox
   - Route: `/sign-up`

5. **Forget Password Screen** (`forget_password_screen.dart`)
   - Email input for password reset
   - Sends OTP to email
   - Route: `/forget-password`

6. **Verify OTP Screen** (`verify_otp_screen.dart`)
   - OTP verification for password reset or registration
   - Route: `/verify-otp`

7. **Reset Password Screen** (`reset_password_screen.dart`)
   - New password input after OTP verification
   - Route: `/reset-password`

### Auth Controller (`auth_controller.dart`)
- Handles login, register, forgot password, reset password
- Uses `ApiService` for API calls
- Manages loading states
- Shows success/error messages

### Auth Service (`auth_service.dart`)
- API service methods for authentication
- Login, register, forgot password, verify OTP endpoints

---

## Profile Screen Section

### Profile Screen (`profile_screen.dart`)
- **Route**: Accessible from bottom navigation (Profile tab)
- **Features**:
  - User profile header (name, greeting, profile picture, plan badge)
  - Settings list with options:
    - Edit Profile
    - Performance Dashboard
    - Change Password
    - Subscription
    - Privacy Policy
    - Terms of Service
    - FAQ
    - Contact Us
    - Log Out (clears all data and cache, navigates to onboarding)

### Profile Related Screens:
1. **Edit Profile Screen** (`edit_profile_screen.dart`)
   - Profile picture upload (camera/gallery)
   - Name editing
   - Route: `/edit-profile`

2. **Change Password Screen** (`change_password_screen.dart`)
   - Current password, new password, confirm password
   - Success dialog on completion
   - Route: `/change-password`

3. **Subscribe Screen** (`subscribe_screen.dart`)
   - Starter Plan display
   - Upgrade to Professional button
   - Route: `/subscribe`

4. **Professional Plan Screen** (`professional_plan_screen.dart`)
   - Professional plan details
   - Pricing: $180.00/3 months
   - Features list
   - Route: `/professional-plan`

5. **Privacy Policy Screen** (`privacy_policy_screen.dart`)
   - Privacy policy content
   - Route: `/privacy-policy`

6. **Terms of Service Screen** (`terms_of_service_screen.dart`)
   - Terms and conditions
   - Route: `/terms-of-service`

7. **FAQ Screen** (`faq_screen.dart`)
   - Frequently asked questions
   - Route: `/faq`

8. **Contact Us Screen** (`contact_us_screen.dart`)
   - Contact form (email, phone, subject, description)
   - Image attachment
   - Route: `/contact-us`

### Profile Features:
- **Logout Functionality**:
  - Clears all SharedPreferences data
  - Clears all cache (temp, app cache, image cache)
  - Clears Flutter image cache
  - Navigates to onboarding screen

- **Storage Service** (`storage_service.dart`):
  - Token management
  - User ID management
  - Login status
  - Complete logout with cache clearing

---

## Navigation Flow

### Auth Flow:
```
Splash → Onboarding → Login/Sign Up → Home (Navbar)
```

### Profile Flow:
```
Home (Navbar) → Profile Tab → Settings Options → Various Screens
```

### Logout Flow:
```
Profile → Log Out → Clear All Data & Cache → Onboarding
```
