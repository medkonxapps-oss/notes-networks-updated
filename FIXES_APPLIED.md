# 🔧 Fixes Applied — Notes-Network

## 🐛 Bug Fixes

### 1. Forgot Password — Complete Working Flow
**File:** `packages/app/lib/features/auth/screens/forgot_password_screen.dart`
- Added success state after sending reset email
- "Enter Code & Reset Password" button appears after email is sent  
- Resend option available
- `auth_service.dart`: Added `redirectTo: 'io.notesnet.app://login-callback'` to `resetPasswordForEmail`

**File:** `packages/app/lib/core/router/app_router.dart`
- Added `/auth/reset-password` route so deep link navigation works

---

### 2. Push Notifications — Now Working on Phone
**File:** `packages/app/lib/main.dart`
- ✅ Added `Firebase.initializeApp()` — was completely missing before
- ✅ Added `FirebaseMessaging.onBackgroundMessage` top-level handler

**File:** `packages/app/lib/shared/providers/notification_provider.dart`
- ✅ Added `FlutterLocalNotificationsPlugin` — foreground FCM notifications now actually show
- ✅ Created Android high-importance notification channel
- ✅ Added iOS foreground notification options
- ✅ Handles token refresh
- ✅ Handles `onMessageOpenedApp` (background tap) and `getInitialMessage` (terminated tap)

---

### 3. Real-time Like / Save Updates
**File:** `packages/app/lib/shared/providers/providers.dart`
- Added `_savesRealtimeProvider` — Supabase realtime stream on `saves` table per user
- Added `_likesRealtimeProvider` — Supabase realtime stream on `likes` table per user
- `savedNotesProvider` now watches `_savesRealtimeProvider` → auto-refreshes when any device likes/saves
- `likedNotesProvider` now watches `_likesRealtimeProvider`

**File:** `packages/app/lib/features/note_detail/screens/note_detail_screen.dart`
- `_toggleLike` now calls `ref.invalidate(likedNotesProvider)`
- `_toggleSave` now calls `ref.invalidate(savedNotesProvider)`

---

### 4. OTP Screen — Working Resend Button
**File:** `packages/app/lib/features/auth/screens/otp_screen.dart`
- Resend now calls `supabase.auth.resend(type: OtpType.signup, ...)`
- 60-second cooldown timer after each resend
- Success/error feedback shown

---

### 5. Notification Preferences — Actually Saves
**File:** `packages/app/lib/features/settings/screens/notification_prefs_screen.dart`
- `_loadPrefs()` now reads `notification_preferences` JSONB from `users` table on screen open
- `_save()` now writes all toggle states to `notification_preferences` JSONB column

---

## 🔒 Security Fixes

### 6. Signup — Password Confirmation + Strong Validation
**File:** `packages/app/lib/features/auth/screens/signup_screen.dart`
- Added "Confirm Password" field
- Password validation now requires: **8+ chars + 1 uppercase + 1 number**
- Both signup and change-password screens consistent

---

### 7. Change Password — Verifies Current Password
**File:** `packages/app/lib/features/settings/screens/change_password_screen.dart`
- Added "Current Password" field
- Re-authenticates with Supabase before allowing password change
- Prevents unauthorized password changes if phone is unlocked
- New password must differ from current password

---

### 8. Login — Client-Side Rate Limiting
**File:** `packages/app/lib/features/auth/screens/login_screen.dart`
- After **5 failed attempts**: 30-second lockout with countdown timer
- Button shows "Try again in Xs" during lockout
- Failed attempts reset on successful login

---

### 9. Username Sanitization
**File:** `packages/shared/lib/services/auth_service.dart`
- Added `_sanitizeUsername()` method
- Strips invalid characters (only `a-z`, `0-9`, `_`, `-` allowed)
- Validated server-side via DB constraint in migration 018

---

### 10. Webhook — Timing-Safe Secret Comparison
**File:** `backend/src/routes/webhook.ts`
- Replaced `===` string compare with `crypto.timingSafeEqual()`
- Prevents timing-based secret guessing attacks
- Added IP logging for failed verification attempts

---

### 11. Backend — Tightened Request Limits
**File:** `backend/src/index.ts`
- Reduced body size limit from `5mb` → `1mb`
- Added request ID logging (non-sensitive)
- Disabled `X-Powered-By` header

---

### 12. Session Expiry Handling
**File:** `packages/app/lib/app.dart`
- On sign-out / session expiry: clears `feedProvider`, `savedNotesProvider`, `likedNotesProvider`
- Router's redirect handles navigation to `/auth/login`

---

### 13. Realtime Subscription Guard
**File:** `packages/app/lib/shared/providers/providers.dart`
- `noteStatsSyncProvider` now checks `auth.currentUser?.id` before subscribing
- Prevents orphan subscriptions when not authenticated

---

## 🗄️ Database

### 14. Migration 018
**File:** `supabase/migrations/018_security_and_fixes.sql`
- Adds `notification_preferences` JSONB column
- Adds `failed_login_attempts` + `last_failed_login_at` columns
- Adds performance indexes: notifications, likes, saves, notes feed, follows
- Adds DB-level username format constraint (`^[a-z0-9_\-]{3,30}$`)
- Cleans up empty-string FCM tokens (replaces with `null`)

---

## 📋 How to Apply

1. Run `supabase/migrations/018_security_and_fixes.sql` on your Supabase project
2. Replace `packages/app`, `packages/shared`, `backend` folders
3. Ensure `FIREBASE_SERVICE_ACCOUNT` env var is set on your backend
4. Ensure `google-services.json` is present in `android/app/`
