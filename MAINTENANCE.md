# Durgasevak App Maintenance Guide

This document outlines the steps required to keep the cloud sync functionality of the Durgasevak app running for free on Render.com.

## Architecture Overview
- **Mobile App**: Completely offline-first. Your data is always saved locally on your Android device in a SQLite database. **Your Admin phone is the master backup.**
- **Cloud Backend**: Hosted on Render (Web Service).
- **Cloud Database**: Hosted on Render (PostgreSQL). Used purely as a temporary storage tunnel to sync data between the Admin phone and Viewer phones.

---

## The 30-Day Database Reset (Required Maintenance)

Render's Free PostgreSQL databases automatically expire and are deleted after **30 days**. 
When this happens, the "Upload to Cloud" button in the app will start showing errors because the cloud database no longer exists.

**How to fix it (Takes 2 minutes):**

1. Log into your account at [Render.com](https://render.com/).
2. Click **New+** -> **PostgreSQL**.
3. Name it `durgasevak_db` (or anything else) and click **Create Database** (it's completely free).
4. Wait about 30 seconds for it to say "Available".
5. Scroll down and copy the **Internal Database URL** (it looks like `postgres://...`).
6. Go to your **Web Service** dashboard (durgasevak-backend).
7. Click on the **Environment** tab on the left menu.
8. Find the `DATABASE_URL` variable, delete the old value, and paste the new URL you just copied.
9. Click **Save Changes**. Render will automatically restart your server.
10. Open the Durgasevak app on your Admin phone and click **Upload to Cloud**. Your data is now successfully restored to the cloud for another 30 days!

### Want to avoid doing this every month?
If you want a free permanent database that never expires, sign up for a free account at [Neon.tech](https://neon.tech/). Create a project, copy the "Connection String" they give you, and paste it into the `DATABASE_URL` Environment Variable in Render instead.

---

## Server Sleep Time (Normal Behavior)

Render's Free Web Services go to "sleep" if no one makes a request for 15 minutes. 
- **What this means:** The very first time you click "Upload" or "Download" on a given day, it might take **40 to 50 seconds** for the app to respond because the server is waking up.
- **Action:** Just be patient and don't close the app! Once it wakes up, it will be lightning-fast for the rest of your session.
