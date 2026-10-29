# My Profile screen

## Reference

Figma node `133:380` in the Food Delivery App UI Kit, frame 4.1.1-I.

## Layout and behavior

- Yellow header with a back action and centered “Hồ sơ của tôi” title.
- Light surface with rounded top corners, centered profile image and camera badge.
- Tapping the avatar or camera badge opens the image library. JPEG, PNG and
  WebP files are accepted up to 1 MB after resizing and decoded before preview.
- Editable full name, date of birth and phone number fields; email is displayed
  as read-only because account email is managed by Firebase Authentication.
- Date of birth uses a date picker and is stored as `yyyy-MM-dd` at
  `/users/{uid}/dateOfBirth`.
- “Cập nhật hồ sơ” saves the editable fields through `AuthBloc` and
  `AuthService`, shows loading state, then reports success or a localized error.
- Profile images are resized to 512 × 512 and stored as a base64 data URL in
  `/users/{uid}/image`. This uses the existing authenticated Realtime Database
  profile because the configured Firebase Storage bucket is unavailable.
- JPEG, PNG and WebP are validated by their file signatures, decoded before
  preview, and limited to 1 MB after resizing to keep profile writes bounded.
- The form validates full name, date of birth, stored email and phone number
  before any profile update is sent.
- The screen is opened from the existing profile menu and keeps the shared
  client bottom navigation component.
