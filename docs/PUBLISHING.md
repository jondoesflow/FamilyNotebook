# Getting Notebook onto your phones with TestFlight, without a Mac

You never need a Mac. GitHub Actions rents a Mac in the cloud, builds the app, signs it, and uploads it to App Store Connect. You only use a web browser and your iPhone.

```
GitHub repo ──push / "Run workflow"──▶ GitHub Actions (macOS + Xcode)
                                          │  xcodegen → fastlane match → build → upload
                                          ▼
                                   App Store Connect ──▶ TestFlight ──▶ Jon & Katie's iPhones
```

**What you need:** an Apple Developer Program membership ($99 a year, at developer.apple.com/programs). TestFlight only works with one. Both of you also need to be signed in to iCloud on your phones.

**Time:** about 45 minutes once, then one click for each update.

---

## 1. Register the app with Apple (developer.apple.com)

Go to **Certificates, IDs & Profiles**.

1. **Create the iCloud container**
   *Identifiers* → **+** → **iCloud Containers** → Continue
   - Description: `Family Notebook`
   - Identifier: `iCloud.com.jondoesflow.FamilyNotebook`

2. **Create the App ID**
   *Identifiers* → **+** → **App IDs** → **App** → Continue
   - Description: `Family Notebook`
   - Bundle ID: **Explicit**, `com.jondoesflow.FamilyNotebook`
   - Capabilities: tick **iCloud** (choose *Include CloudKit support*) and **Push Notifications**
   - Continue → Register

3. **Connect the container to the App ID**
   Open the new App ID → next to iCloud click **Configure** (or **Edit**) → tick `iCloud.com.jondoesflow.FamilyNotebook` → Continue → **Save**.

4. **Note your Team ID.** It's 10 characters, shown under *Membership details* (or top-right of the portal).

> To use different identifiers, change `APP_BUNDLE_ID` and `CLOUDKIT_CONTAINER` in `project.yml` so they match.

## 2. Create the app record (appstoreconnect.apple.com)

**Apps** → **+** → **New App**
- Platform: iOS
- Name: this must be unique across the whole App Store, so `Notebook` is taken. Try something like **Jon & Katie's Notebook**. The name under the icon on your phone is still **Notebook**.
- Primary language: English (UK)
- Bundle ID: pick `com.jondoesflow.FamilyNotebook`
- SKU: `familynotebook`
- User access: Full

## 3. Create an API key for GitHub

App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys** → **+**
- Name: `GitHub Actions`
- Access: **Admin** (it has to be able to create your signing certificate)
- **Download** the `.p8` file. You can only download it once, so keep it somewhere safe.
- Copy the **Key ID** (next to the key) and the **Issuer ID** (above the table).

## 4. Add secrets to the GitHub repo

GitHub → `jondoesflow/FamilyNotebook` → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**. Add these five:

| Name | Value |
|---|---|
| `ASC_KEY_ID` | The Key ID from step 3 |
| `ASC_ISSUER_ID` | The Issuer ID from step 3 |
| `ASC_KEY_P8` | The whole contents of the `.p8` file, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines. Open it in Notepad and copy it. |
| `TEAM_ID` | Your 10-character Team ID |
| `MATCH_PASSWORD` | A long random password (30+ characters) from a password manager. Keep a copy in the password manager too. |

> **Why MATCH_PASSWORD?** On the first run, fastlane *match* creates your Apple Distribution certificate and App Store provisioning profile. It encrypts them with this password and stores them on a branch called `match-certificates` in this repo, so every later build reuses them. Your repo is **public**, so a strong password matters. If you'd rather make the repo private, that works too. Mac build minutes then count against GitHub's free allowance (roughly 10–15 builds a month).

## 5. First build: iCloud *Development*

iCloud has two separate databases, Development and Production. The Production one has to be told about the app's data model first, so the first build uses Development.

1. GitHub → **Actions** → **iOS** → **Run workflow**
   - Upload to TestFlight: ✅
   - iCloud environment: **Development**
2. Wait about 15–20 minutes for a green tick. If it fails, open the run, read the red step, and see *Troubleshooting* below.
3. In App Store Connect → your app → **TestFlight**, the build appears as *Processing* for 5–30 minutes.

## 6. Install it on both phones

1. App Store Connect → **Users and Access** → **+** → invite **Katie** with her Apple ID email. Any role is fine, for example *Marketing*. She accepts the email invite.
2. App Store Connect → your app → **TestFlight** → **Internal Testing** → **+** → create a group called `Us` → add **yourself** and **Katie** → turn on *Automatic distribution*.
3. You'll both get an email. Install **TestFlight** from the App Store, open the invite and tap **Install**.

The app asks for no export-compliance answers. That's already handled in the project.

## 7. Push the data model to Production

1. Open Notebook on **your** phone and pick "Jon". In a Development build the app automatically uploads its data model to iCloud the first time it launches. Leave it open for about 30 seconds on Wi-Fi.
2. Go to **icloud.developer.apple.com** → **CloudKit Console** → **CloudKit Database** → pick `iCloud.com.jondoesflow.FamilyNotebook`.
3. In the left sidebar under *Schema*, check that **Record Types** includes `CD_Notebook`, `CD_Note`, `CD_Attachment`, `CD_TripItem` and `CD_Expense`.
4. Click **Deploy Schema Changes…** (bottom-left) → **Deploy**.

## 8. Real build: iCloud *Production*

**Actions** → **iOS** → **Run workflow** → TestFlight ✅, environment **Production**.

Install the update from TestFlight on both phones. Anything you wrote in the Development build stays there and won't show up now. That's expected, because the two are separate databases.

## 9. Share a notebook with Katie

1. Create a notebook. Tap the **person+** icon at the top right, or long-press the cover → *Share with Katie*.
2. Send the link by Messages.
3. Katie taps the link and it opens in Notebook. The notebook appears on her shelf with your two avatars on it. Anything either of you writes syncs within a few seconds.

Share as many notebooks as you like. Ones you don't share stay private.

---

## Shipping updates

Any time the code changes:
**Actions** → **iOS** → **Run workflow** (Production). TestFlight updates both phones automatically.

Every push also runs a quick *build-only* check. It needs no secrets and confirms the code still compiles.

**TestFlight builds expire after 90 days.** Run the workflow again before then. The app shows a banner in TestFlight when expiry is close.

## Putting it on the public App Store (optional)

You don't need to. TestFlight is ideal for two people. If you ever want to:
1. App Store Connect → your app → **Distribution**: add screenshots (6.9" iPhone), a description, keywords, a support URL and a privacy policy URL. A one-page site saying "we collect nothing; your notes live in your own iCloud" is enough.
2. **App Privacy** → *Data Not Collected*.
3. Choose the TestFlight build → **Add for Review** → **Submit**. Review usually takes 1–2 days.
4. To keep it to the two of you, under **Pricing and Availability** you can choose **Unlisted app distribution**. That needs a request form, and Apple then gives you a private link.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Missing repository secret …` | Add the secret named in the error (step 4). |
| `No App ID found for bundle identifier` | The App ID from step 1.2 doesn't exist, or its bundle ID doesn't match `project.yml`. |
| `Could not create another Distribution certificate, reached the maximum` | Apple allows 2–3. Revoke an old one under *Certificates*, then rerun. |
| Provisioning profile "doesn't include the iCloud container" | Do step 1.3, then delete the `match-certificates` branch so match makes a new profile, and rerun. |
| Upload fails with `app record not found` | Do step 2. The bundle ID must match. |
| `The bundle version must be higher` | Each run uses GitHub's run number, so rerunning the workflow fixes it. |
| Nothing syncs | Settings → Notebook's **Sync** section shows the iCloud status. Both phones must be signed in to iCloud, and in step 7 the schema must be deployed **before** the Production build is used. |
| Katie's link says "app not installed" | She needs the TestFlight build installed before tapping the link. |
