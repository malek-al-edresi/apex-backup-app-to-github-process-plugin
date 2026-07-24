# Installation and Configuration Guide

This guide walks you through installing and configuring the **Backup APEX App to GitHub** process plugin step by step.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Create a GitHub Personal Access Token](#2-create-a-github-personal-access-token)
3. [Configure the Network ACL](#3-configure-the-network-acl)
4. [Prepare the Target Repository](#4-prepare-the-target-repository)
5. [Import the Plugin](#5-import-the-plugin)
6. [Add the Process to a Page](#6-add-the-process-to-a-page)
7. [Configure Plugin Attributes](#7-configure-plugin-attributes)
8. [Test the Backup](#8-test-the-backup)
9. [Usage Example: Backup on Button Click](#9-usage-example-backup-on-button-click)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites

Before you begin, make sure you have:

- **Oracle APEX 24.1 or later** installed and running.
- **Oracle Database 19c or later**.
- **Workspace administrator** or developer access in your APEX workspace.
- A **GitHub account** with at least one repository.
- **DBA access** (or DBA assistance) to configure network ACLs.

---

## 2. Create a GitHub Personal Access Token

The plugin needs a GitHub token to authenticate API requests.

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens).
2. Click **Generate new token (classic)**.
3. Give it a descriptive name, for example: `APEX Backup Plugin`.
4. Select the **repo** scope (this grants read/write access to repository contents).
5. Click **Generate token**.
6. **Copy the token immediately** -- you will not be able to see it again.

> **Note:** For fine-grained tokens, grant **Contents: Read and write** permission on the target repository.

---

## 3. Configure the Network ACL

Oracle Database blocks outbound HTTP requests by default. Your DBA must create an Access Control List (ACL) to allow APEX to reach the GitHub API.

Connect to the database as `SYS` or a privileged user and run:

```sql
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => 'api.github.com',
        lower_port => 443,
        upper_port => 443,
        ace        => xs$ace_type(
            privilege_list => xs$name_list('http'),
            principal_name => 'YOUR_APEX_SCHEMA',   -- e.g. MEDICAL_CENTER_SYSTEM
            principal_type => xs_acl.ptype_db
        )
    );
    COMMIT;
END;
/
```

Replace `YOUR_APEX_SCHEMA` with the parsing schema of your APEX application.

To verify the ACL was created:

```sql
SELECT host, lower_port, upper_port, principal
  FROM dba_host_aces
 WHERE host = 'api.github.com';
```

---

## 4. Prepare the Target Repository

The plugin **updates existing files** on GitHub. Before running the plugin for the first time, you must create a placeholder file in the repository at the path you plan to use.

For example, if you use the default file path `apex/app_100_latest.sql`:

1. Go to your GitHub repository.
2. Click **Add file** then **Create new file**.
3. Enter the path: `apex/app_100_latest.sql`
4. Add any placeholder content (for example, `-- initial placeholder`).
5. Click **Commit new file**.

---

## 5. Import the Plugin

1. Log in to your Oracle APEX workspace.
2. Open the target application.
3. Navigate to **Shared Components** (via the application home page).
4. Under **Other Components**, click **Plug-ins**.
5. Click **Import**.
6. Click **Choose File** and select `process_type_plugin_backup_apex_app_to_github.sql`.
7. Click **Next**, then **Install Plug-in**.
8. After import, you should see **Backup APEX App to GitHub** listed under your plug-ins.

---

## 6. Add the Process to a Page

1. Open a page in **Page Designer** (or create a new page).
2. In the left pane, expand **Processing** and right-click **Processes**.
3. Click **Create Process**.
4. In the right property pane, set:
   - **Name**: `Backup to GitHub` (or any descriptive name).
   - **Type**: Select **Backup APEX App to GitHub** from the Plug-in list.

---

## 7. Configure Plugin Attributes

After selecting the plugin type, the **Settings** section appears in the property pane with six fields:

| Attribute | What to Enter | Example |
|-----------|---------------|---------|
| **Application ID** | The numeric ID of the app to export. Use `:APP_ID` for the current application. | `:APP_ID` |
| **GitHub Token** | Your personal access token from Step 2. | `ghp_abc123def456...` |
| **Repository Owner** | Your GitHub username or organization name. | `eng-malek` |
| **Repository Name** | The exact repository name. | `my-apex-backups` |
| **Branch** | The branch to commit to. Leave as `main` for default. | `main` |
| **File Path** | Path and filename in the repo. Leave blank for the default (`apex/app_{ID}_latest.sql`). | `backups/app_100.sql` |

The screenshot below shows these settings in Page Designer:

![Plugin settings in Page Designer](images/page-designer-settings.png)

### Execution Settings

Under the **Execution** section, configure:

- **Sequence**: The order of execution relative to other processes (for example, `10`).
- **Point**: `Processing` (runs when the page is submitted).
- **Run Process**: `Once Per Page Visit (default)`.

### Server-Side Condition (Optional)

To run the backup only when a specific button is clicked:

- **Type**: `Request = Value`
- **Value**: The button's request name (for example, `BACKUP`).

---

## 8. Test the Backup

1. **Enable Debug Mode** in your APEX application (useful for troubleshooting).
2. Run the page and trigger the process (click the button or submit the page).
3. If successful, you will see a success message like:
   ```
   Application 100 backed up to eng-malek/my-apex-backups/blob/main/backups/app_100.sql (commit pending)
   ```
4. Open your GitHub repository and confirm the file has been updated.

---

## 9. Usage Example: Backup on Button Click

This example creates a simple page with a button that backs up the current application.

### Step 1 -- Create the Button

1. Open a page in Page Designer.
2. Add a **Button** to any region.
3. Set the button properties:
   - **Button Name**: `BACKUP`
   - **Label**: `Backup to GitHub`
   - **Action**: `Submit Page`

### Step 2 -- Create the Process

1. Under **Processing** > **Processes**, create a new process.
2. Set Type to **Backup APEX App to GitHub**.
3. Fill in the six attributes (see Step 7 above).
4. Under **Server-side Condition**:
   - **Type**: `Request = Value`
   - **Value**: `BACKUP`

### Step 3 -- Add a Success Message

1. Under **Success Message** in the process properties, enter:
   ```
   Backup completed successfully.
   ```

### Step 4 -- Run and Verify

1. Run the page.
2. Click the **Backup to GitHub** button.
3. Check your GitHub repository for the updated file.

---

## 10. Troubleshooting

### Common Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `File ... does not exist on GitHub. This plugin only updates existing files (no create).` | The target file path does not exist in the repository. | Create a placeholder file at that path in your GitHub repo (see Step 4). |
| `HTTP 401 from GitHub` | The token is invalid, expired, or revoked. | Generate a new token with the `repo` scope. |
| `HTTP 403 from GitHub` | The token does not have permission for this repository. | Verify token scopes. For organization repos, ensure the token is authorized for the org. |
| `GitHub upload failed: HTTP 422` | The payload is malformed or the SHA is stale. | This may happen if another commit was made between the SHA lookup and the PUT. Retry the process. |
| `ORA-29273: HTTP request failed` | The database cannot reach `api.github.com`. | Verify the network ACL is configured (see Step 3). Check if a proxy is required. |
| `Valid Application ID is required.` | The Application ID attribute is empty or not a positive number. | Enter a valid numeric App ID or use `:APP_ID`. |
| `A valid GitHub token is required.` | The token is empty or shorter than 10 characters. | Paste the full token value. |
| `Application X not found.` | The App ID does not exist in the current workspace. | Check the App ID under **App Builder** in your workspace. |

### Debugging Tips

1. **Enable Debug Mode**: In the APEX Developer Toolbar, click **Debug** to turn on debug logging.
2. **View Debug Logs**: Go to the APEX application home page, then **Utilities** > **Debug Messages**.
3. The plugin logs:
   - The Application ID being exported.
   - The repository, branch, and file path.
   - The first 4 characters of the token (for verification without exposing it).
   - The export file size.
   - Any error messages from GitHub.

### Network Troubleshooting

If you suspect a network issue, test connectivity from SQL:

```sql
DECLARE
    l_response CLOB;
BEGIN
    l_response := apex_web_service.make_rest_request(
        p_url         => 'https://api.github.com',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(l_response));
END;
/
```

If this fails with `ORA-29273`, the ACL is not configured correctly.

---

## Next Steps

- **Automate backups** using APEX Automations (the plugin supports Automation Actions).
- **Use APEX Substitution Strings** to store the GitHub token securely instead of hard-coding it.
- **Set up multiple processes** to back up different applications to different repositories.

For questions or issues, visit the [GitHub Issues page](https://github.com/eng-malek/apex-backup-app-to-github-process-plugin/issues).
