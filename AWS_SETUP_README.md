# AWS EC2 Setup Guide — Co-Pricing Factor Zoo

A step-by-step guide to launching an AWS EC2 instance, running the full Bayesian
replication pipeline, and retrieving results. Covers **macOS**, **Linux**, and
**Windows**.

---

## Overview

This repository runs a compute-intensive research pipeline that estimates
Bayesian factor pricing models using Markov Chain Monte Carlo (MCMC) methods.
The pipeline parallelises across all available CPU cores, so more cores means
shorter runtimes. A 32-core cloud server completes the full replication in
roughly 80 minutes — work that would take 4–6 hours on a typical laptop.

This guide walks you through every step: creating an AWS account, launching a
server, connecting to it, running the pipeline with Claude Code, and copying the
results back to your local machine.

**Estimated time:** ~20 minutes of setup, then ~80 minutes of unattended
pipeline runtime on the recommended instance.

> **Note:** For details on the pipeline itself — what it produces, how to
> interpret results — see the [main README](README.md) and
> [QUICKSTART.md](QUICKSTART.md).

---

## Prerequisites

Before you begin, make sure you have the following:

1. **An AWS account.** If you do not have one, create a free account at
   [https://aws.amazon.com/free/](https://aws.amazon.com/free/). A credit card
   is required for billing, but you will only be charged for the resources you
   use. **Note:** New accounts can take up to 24 hours to fully activate. You
   can sign in to the console during this period, but EC2 instance launches may
   fail until activation completes. Sign up early if you are creating a new
   account.

2. **An Anthropic account with a paid plan.** Claude Code requires a Pro, Max,
   or Team subscription (or API credits). A free-tier account will not work.
   Sign up or upgrade at [https://claude.ai/](https://claude.ai/) if you have
   not already.

3. **A terminal application on your local machine.** This is the program you
   use to type commands:
   - **macOS:** Terminal (built-in — open it from Applications → Utilities, or
     search Spotlight for "Terminal")
   - **Linux:** Any terminal emulator (e.g., GNOME Terminal, Konsole)
   - **Windows 10/11:** PowerShell or Windows Terminal (both include SSH
     support by default on Windows 10 version 1809 and later)
   - **Older Windows versions:** Download [PuTTY](https://www.putty.org/), a
     free SSH client — see [Appendix A](#appendix-a--connecting-with-putty-windows) below

---

## Part 1 — Launch an EC2 Instance

An EC2 instance is a virtual server that you rent from AWS. You choose its
size (CPU, memory), operating system, and region, then pay by the hour for
the time it runs.

### Step 1.0 — Check your vCPU quota (important for new accounts)

New AWS accounts have default limits on how many virtual CPUs you can use per
instance family. The compute-optimised instances recommended in this guide (the
**C** family) often have a default quota of **0 vCPUs** on brand-new accounts.
If you skip this step, you may see an error like *"You have requested more vCPU
capacity than your current vCPU limit"* when you try to launch.

**Check and request an increase now — it can take minutes to hours to approve,
so do this first:**

1. Go to the **Service Quotas** console at
   [https://console.aws.amazon.com/servicequotas/](https://console.aws.amazon.com/servicequotas/).
2. In the left sidebar, click **AWS services**, then search for **Amazon EC2**.
3. Search for **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances**.
4. Check the **Applied quota value**. You need at least **32** for a
   `c7i.8xlarge` (or **48** for `c7i.12xlarge`).
5. If the value is too low, click on the quota name, then click
   **Request increase at account level**.
6. Enter **64** as the new value (gives headroom for the recommended instance
   types) and submit the request.

> **Note:** Quota increases for moderate values (e.g., 64 vCPUs) are typically
> approved within 5–30 minutes. Larger requests may take longer and require a
> business justification. You can proceed with the remaining setup steps while
> you wait — just return here to confirm the increase was approved before
> clicking Launch in Step 1.8.

### Step 1.1 — Open the EC2 Console

1. Sign in to the AWS Management Console at
   [https://console.aws.amazon.com/](https://console.aws.amazon.com/).
2. In the search bar at the top, type **EC2** and select **EC2** from the
   results to open the EC2 Dashboard.
3. Make sure the **Region** selector in the top-right corner shows a region
   near you. For North America, **US East (N. Virginia) — us-east-1** is a
   good default. The region affects latency and pricing slightly.

### Step 1.2 — Launch the instance

1. Click the orange **Launch Instance** button.
2. Under **Name and tags**, enter a descriptive name — for example,
   `factor-zoo-replication`.

### Step 1.3 — Choose an operating system (AMI)

An AMI (Amazon Machine Image) is a pre-configured operating system template.

1. Under **Application and OS Images**, select **Ubuntu**.
2. In the dropdown, choose **Ubuntu Server 24.04 LTS (HVM), SSD Volume Type**.
3. Leave the architecture as **64-bit (x86)**.

### Step 1.4 — Choose an instance type

The instance type determines how many CPUs and how much memory your server has.
The pipeline is CPU-bound, so a compute-optimised instance (the **c7i** family)
offers the best price-to-performance ratio.

| Instance | vCPUs | RAM | Approx. Cost (USD/hr) | Est. Pipeline Runtime |
|----------|------:|----:|----------------------:|----------------------:|
| `c7i.4xlarge` | 16 | 32 GB | $0.71 | ~2.5 hours |
| `c7i.8xlarge` | 32 | 64 GB | $1.43 | ~80 minutes |
| `c7i.12xlarge` | 48 | 96 GB | $2.14 | ~55 minutes |

*Prices are on-demand rates for us-east-1 (Linux). Current pricing:
[https://aws.amazon.com/ec2/pricing/on-demand/](https://aws.amazon.com/ec2/pricing/on-demand/)*

**Recommended:** `c7i.8xlarge` — a good balance of speed and cost. The full
pipeline run costs approximately $1.90 in compute time.

1. In the **Instance type** dropdown, search for `c7i.8xlarge` and select it.

> **Tip:** If `c7i` instances are not available in your region, `c6i.8xlarge`
> is a close alternative at a slightly lower price point.

### Step 1.5 — Create a key pair

A key pair is how you authenticate when connecting to your instance. AWS
generates two files: a **public key** (stored on the server) and a **private
key** (a `.pem` file downloaded to your machine). The `.pem` file is a
cryptographic credential — think of it as the only key to a locked door. Anyone
who has it can access your server.

1. Under **Key pair (login)**, click **Create new key pair**.
2. Enter a name — for example, `factor-zoo-key`.
3. Select **RSA** as the key pair type.
4. Select **.pem** as the file format.
   - If you plan to use PuTTY on Windows, select **.ppk** instead.
5. Click **Create key pair**. Your browser will download the file (e.g.,
   `factor-zoo-key.pem`).
6. Note where the file was saved — typically your `Downloads` folder.

> **Important:** Store this file securely and do not share it. If you lose it,
> you will not be able to connect to your instance. AWS does not store a copy
> of the private key. See the
> [AWS Key Pairs documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
> for further details.

### Step 1.6 — Configure the security group

A security group acts as a firewall for your instance. It controls which
network traffic is allowed in and out.

1. Under **Network settings**, click **Edit**.
2. Select **Create security group**.
3. Give it a name — for example, `factor-zoo-ssh`.
4. Under **Inbound security group rules**, you should see a default rule for
   SSH. Configure it as follows:
   - **Type:** SSH
   - **Port range:** 22
   - **Source type:** **My IP** (AWS will auto-detect your current IP address)

> **Security note:** Selecting "My IP" restricts access to your current
> location. Avoid selecting "Anywhere" (0.0.0.0/0), which opens SSH access to
> the entire internet.

### Step 1.7 — Configure storage

1. Under **Configure storage**, set the root volume size to **30 GiB**.
2. Leave the volume type as **gp3** (general-purpose SSD).

The repository, R packages, and generated outputs together use roughly 2–3 GB.
The additional headroom avoids any risk of running out of disk space during
installation or compilation.

### Step 1.8 — Launch

1. Review your configuration in the **Summary** panel on the right.
2. Click **Launch instance**.
3. You will see a confirmation page. Click **View all instances** to return to
   the Instances list.

### Step 1.9 — Find your instance's public IP address

Your instance will take 30–60 seconds to initialise.

1. In the **Instances** list, wait until the **Instance state** column shows
   **Running** and the **Status check** column shows **2/2 checks passed**.
2. Select your instance by clicking its row.
3. In the details panel below, find **Public IPv4 address** — for example,
   `54.201.83.112`.
4. Copy this address. You will need it in the next section.

> **Tip:** You can also use the **Public IPv4 DNS** value (e.g.,
> `ec2-54-201-83-112.us-west-2.compute.amazonaws.com`) — it resolves to the
> same IP.

---

## Part 2 — Connect to Your Instance

SSH (Secure Shell) is a protocol that opens an encrypted terminal session on a
remote machine. You type commands on your local computer, and they execute on
the server.

Throughout this section, replace the example values with your own:
- **Key file:** `factor-zoo-key.pem` → your actual key file name
- **IP address:** `54.201.83.112` → your instance's public IPv4 address

### macOS / Linux

Open a terminal and run:

```bash
# Restrict the key file permissions (SSH requires this)
chmod 400 ~/Downloads/factor-zoo-key.pem

# Connect to your instance
ssh -i ~/Downloads/factor-zoo-key.pem ubuntu@54.201.83.112
```

The `chmod 400` command sets the file permissions so that only your user account
can read the key. SSH will refuse to connect if the key file is accessible to
other users on the system.

### Windows 10 / 11 (PowerShell or Windows Terminal)

Open PowerShell. Before connecting, you must restrict the key file's permissions.
Windows allows multiple user accounts to read downloaded files by default, and
SSH will refuse to use a key that others can access.

Run these three commands to lock down the file (replace `YourName` with your
Windows username throughout):

```powershell
# Remove inherited permissions from the key file
icacls "C:\Users\YourName\Downloads\factor-zoo-key.pem" /inheritance:r

# Grant only your account read-only access
icacls "C:\Users\YourName\Downloads\factor-zoo-key.pem" /grant:r "YourName:(R)"

# Remove any other users/groups that may still have access
icacls "C:\Users\YourName\Downloads\factor-zoo-key.pem" /remove "BUILTIN\Users" "NT AUTHORITY\Authenticated Users" "BUILTIN\Administrators"
```

You should see `Successfully processed 1 files` after each command. Now connect:

```powershell
ssh -i C:\Users\YourName\Downloads\factor-zoo-key.pem ubuntu@54.201.83.112
```

> **Note:** If PowerShell returns `ssh: The term 'ssh' is not recognized`, the
> OpenSSH client is not installed. To install it:
> 1. Open **Settings** → **Apps** → **Optional features**.
> 2. Click **Add a feature**, search for **OpenSSH Client**, and install it.
> 3. Restart PowerShell and try again.

### Windows (PuTTY)

See [Appendix A](#appendix-a--connecting-with-putty-windows) at the end of this
document for detailed PuTTY instructions.

### First connection prompt

The first time you connect to any new server, your terminal will display a
message like:

```
The authenticity of host '54.201.83.112' can't be established.
ED25519 key fingerprint is SHA256:AbC123xYz...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter. This is a one-time verification step — your
computer is confirming the server's identity before establishing the encrypted
connection.

Once connected, your terminal prompt will change to something like:

```
ubuntu@ip-172-31-42-7:~$
```

You are now running commands on the remote server.

---

## Part 3 — Install and Authenticate Claude Code

Claude Code is a command-line AI assistant that can read, write, and execute
code. In this workflow, it automates the entire environment setup (R, system
libraries, packages, data) and runs the replication pipeline.

### Step 3.1 — Install Claude Code

Run the following command on the server:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

This downloads and runs the official installer. It completes in a few seconds.

### Step 3.2 — Verify the installation

```bash
claude --version
```

You should see output like:

```
claude 2.1.104 (claude-code)
```

If you see `command not found`, add Claude Code to your PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Then run `claude --version` again to confirm.

### Step 3.3 — Authenticate

```bash
claude
```

Claude Code will display a sign-in URL in your terminal:

```
To sign in, open this URL in your browser:
https://claude.ai/oauth/authorize?code=ABCD1234...
```

1. **Copy** the URL from your terminal. (Select the text, then right-click to
   copy — or use Ctrl+Shift+C on Linux / Cmd+C on macOS.)
2. **Paste** the URL into a web browser on your local machine.
3. **Sign in** to your Anthropic account when prompted.
4. Return to your terminal — Claude Code will confirm that authentication
   succeeded.

Type `/exit` to leave Claude Code for now. You will start it again in the next
section from inside the project directory.

---

## Part 4 — Clone the Repository and Run the Pipeline

### Step 4.1 — Clone the repository

```bash
git clone https://github.com/Alexander-M-Dickerson/co-pricing-factor-zoo.git
cd co-pricing-factor-zoo
```

This downloads the full project (code, configuration, documentation) to the
server. The `cd` command moves you into the project directory.

### Step 4.2 — Start a persistent terminal session

The pipeline runs for over an hour. If your SSH connection drops (laptop sleep,
Wi-Fi interruption, terminal closed accidentally), any running process will be
terminated. To prevent this, use `tmux` — a terminal multiplexer that keeps
your session alive on the server even if you disconnect.

```bash
# Install tmux (not included on Ubuntu Server by default)
sudo apt install -y tmux

# Start a named session
tmux new -s pipeline
```

You are now inside a `tmux` session. Everything you run here will survive a
disconnection. If you do get disconnected, reconnect via SSH and reattach:

```bash
tmux attach -t pipeline
```

> **Tip:** To detach from `tmux` without stopping anything, press
> `Ctrl+B` then `D`. To reattach later, run `tmux attach -t pipeline`.

### Step 4.3 — Start Claude Code

```bash
claude
```

Claude Code will load the project configuration automatically.

### Step 4.4 — Set up the environment

Inside the Claude Code session, type:

```
/onboard
```

This command instructs Claude Code to:
- Install R and required system libraries
- Install approximately 80 R packages (including compiled packages)
- Download the canonical public data bundle
- Validate that the environment is ready

**Expected duration:** 5–15 minutes, depending on your instance type and
network speed. Claude Code will display progress throughout.

### Step 4.5 — Run the replication pipeline

Once onboarding completes, type:

```
/replicate-paper
```

This runs the full Bayesian MCMC estimation pipeline: all unconditional factor
models, Internet Appendix models, tables, figures, and the compiled paper PDF.

| Instance | vCPUs | Expected Runtime |
|----------|------:|:----------------:|
| `c7i.4xlarge` | 16 | ~2.5 hours |
| `c7i.8xlarge` | 32 | ~80 minutes |
| `c7i.12xlarge` | 48 | ~55 minutes |

Claude Code will report progress and flag any issues. When the pipeline
completes, all generated outputs are located in:

- `output/` — main paper tables, figures, and PDFs
- `ia/output/` — Internet Appendix tables and figures

---

## Part 5 — Copy Results to Your Local Machine

### Step 5.1 — Package the results on the server

Exit Claude Code (type `/exit`). If you are inside a `tmux` session, you will
return to the tmux shell — this is expected. Then run:

```bash
cd ~/co-pricing-factor-zoo

# Install zip if not already present (not included on Ubuntu Server by default)
sudo apt install -y zip

# Create a dated archive of all outputs
zip -r results_$(date +%Y%m%d).zip output/ ia/output/
ls -lh results_*.zip
```

This creates a dated ZIP archive (e.g., `results_20260413.zip`) containing all
generated outputs. The `ls` command confirms it was created and shows the file
size.

### Step 5.2 — Download the results to your local machine

Open a **new terminal window on your local machine** (not the SSH session) and
use one of the following methods.

#### macOS / Linux

```bash
scp -i ~/Downloads/factor-zoo-key.pem \
    ubuntu@54.201.83.112:~/co-pricing-factor-zoo/results_*.zip \
    ~/Downloads/
```

`scp` (secure copy) transfers files over an encrypted SSH connection using
the same key pair you used to connect.

#### Windows 10 / 11 (PowerShell)

```powershell
scp -i C:\Users\YourName\Downloads\factor-zoo-key.pem `
    ubuntu@54.201.83.112:~/co-pricing-factor-zoo/results_*.zip `
    C:\Users\YourName\Downloads\
```

Replace `YourName` with your Windows username.

#### Windows (WinSCP — graphical interface)

If you prefer a drag-and-drop file transfer:

1. Download and install [WinSCP](https://winscp.net/).
2. Open WinSCP and click **New Session**.
3. Set **File protocol** to **SCP**.
4. Enter your instance IP as the **Host name** (e.g., `54.201.83.112`).
5. Set **Port** to `22` and **User name** to `ubuntu`.
6. Click **Advanced** → **SSH** → **Authentication** → browse to your
   `.pem` file (or `.ppk` if you converted it earlier).
7. Click **Login**.
8. Navigate to `/home/ubuntu/co-pricing-factor-zoo/` on the remote side.
9. Drag the `results_*.zip` file to your desired local folder.

---

## Part 6 — Stop or Terminate Your Instance

You are billed for every hour your instance runs. A `c7i.8xlarge` costs
approximately **$1.43 per hour**, so always shut down your instance once you
have retrieved your results.

### Stop vs. Terminate

| Action | What happens | When to use |
|--------|-------------|-------------|
| **Stop** | The instance pauses. Compute charges stop, but storage charges continue (~$0.08/GB/month for 30 GB = ~$2.40/month). You can restart it later and your files will still be there. **Note:** AWS assigns a new public IP address each time you restart a stopped instance — check the EC2 Console for the updated IP before reconnecting via SSH. | You plan to run additional models or debug results later. |
| **Terminate** | The instance and its storage are permanently deleted. All data on the server is lost. | You have downloaded all results and no longer need the server. |

### How to stop or terminate

1. Go to the EC2 Console at
   [https://console.aws.amazon.com/ec2/](https://console.aws.amazon.com/ec2/).
2. Click **Instances** in the left sidebar.
3. Select your instance by clicking its checkbox.
4. Click **Instance state** (dropdown) at the top.
5. Select **Stop instance** or **Terminate instance**.
6. Confirm when prompted.

> **Important:** Verify that the instance state changes to **Stopped** or
> **Terminated**. If it remains **Running**, you will continue to be charged.

---

## Troubleshooting

| Problem | Likely Cause | Solution |
|---------|-------------|----------|
| `Permission denied (publickey)` | Wrong key file or wrong username | Verify the `.pem` file path is correct. The username for Ubuntu AMIs is `ubuntu` (not `root`, `admin`, or `ec2-user`). |
| `Connection timed out` | Security group, instance state, or network restriction | Confirm the instance is **Running** in the EC2 Console. Check that the security group allows SSH (port 22) from your IP address. If your IP changed (e.g., you switched Wi-Fi networks), update the security group rule. If you are on a corporate or university network, outbound traffic on port 22 may be blocked by a firewall or VPN — try from a personal network or contact your IT department. |
| `WARNING: UNPROTECTED PRIVATE KEY FILE!` | Key file permissions are too open | **macOS/Linux:** run `chmod 400 ~/Downloads/factor-zoo-key.pem`. **Windows:** run the three `icacls` commands from the [Windows connection instructions](#windows-10--11-powershell-or-windows-terminal) in Part 2 to remove inherited permissions and restrict access to your user account only. |
| `ssh: command not found` (Windows) | OpenSSH Client not installed | Open Settings → Apps → Optional features → Add a feature → search for "OpenSSH Client" → Install. Restart PowerShell. |
| `claude: command not found` | PATH not configured | Run: `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc` |
| Claude Code authentication URL does not open | Browser not available on server | Copy the URL from the terminal and paste it into a browser on your **local** machine. You do not need a browser on the server. |
| `/onboard` fails partway through | Transient network or package error | Run `/onboard` again — it detects what is already installed and resumes from where it left off. |
| Instance type not available | Capacity in selected region | Try a different availability zone or region. Alternatively, use `c6i.8xlarge` as a fallback. |
| `vCPU limit exceeded` or instance fails to launch | Account vCPU quota too low | See [Step 1.0](#step-10--check-your-vcpu-quota-important-for-new-accounts) — request a quota increase via the Service Quotas console. |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` | IP address changed after stop/restart, or reused by a new instance | This is expected when an instance's IP changes — not an attack. Remove the old key: **macOS/Linux:** `ssh-keygen -R 54.201.83.112` (replace with the old IP). **Windows PowerShell:** `ssh-keygen -R 54.201.83.112` (same command; works with the built-in OpenSSH). Then reconnect with the new IP. |
| `dpkg lock` or `Could not get lock /var/lib/dpkg/lock-frontend` | Ubuntu is running automatic updates in the background | This happens on freshly launched instances. Wait 1–2 minutes and try the command again. |

---

## Quick Reference

All example values use the key file `factor-zoo-key.pem` and IP `54.201.83.112`.
Replace these with your own.

### macOS / Linux

| Task | Command |
|------|---------|
| Set key permissions | `chmod 400 ~/Downloads/factor-zoo-key.pem` |
| Connect to server | `ssh -i ~/Downloads/factor-zoo-key.pem ubuntu@54.201.83.112` |
| Install Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` |
| Verify Claude Code | `claude --version` |
| Clone repository | `git clone https://github.com/Alexander-M-Dickerson/co-pricing-factor-zoo.git && cd co-pricing-factor-zoo` |
| Start Claude Code | `claude` |
| Run environment setup | `/onboard` |
| Run pipeline | `/replicate-paper` |
| Package results | `zip -r results_$(date +%Y%m%d).zip output/ ia/output/` |
| Download results (local) | `scp -i ~/Downloads/factor-zoo-key.pem ubuntu@54.201.83.112:~/co-pricing-factor-zoo/results_*.zip ~/Downloads/` |

### Windows (PowerShell)

| Task | Command |
|------|---------|
| Set key permissions | `icacls "C:\Users\YourName\Downloads\factor-zoo-key.pem" /inheritance:r` then `/grant:r "YourName:(R)"` then `/remove "BUILTIN\Users" "NT AUTHORITY\Authenticated Users" "BUILTIN\Administrators"` (see [Part 2](#windows-10--11-powershell-or-windows-terminal) for full commands) |
| Connect to server | `ssh -i C:\Users\YourName\Downloads\factor-zoo-key.pem ubuntu@54.201.83.112` |
| Install Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` |
| Verify Claude Code | `claude --version` |
| Clone repository | `git clone https://github.com/Alexander-M-Dickerson/co-pricing-factor-zoo.git; cd co-pricing-factor-zoo` |
| Start Claude Code | `claude` |
| Run environment setup | `/onboard` |
| Run pipeline | `/replicate-paper` |
| Package results | `zip -r results_$(date +%Y%m%d).zip output/ ia/output/` |
| Download results (local) | `scp -i C:\Users\YourName\Downloads\factor-zoo-key.pem ubuntu@54.201.83.112:~/co-pricing-factor-zoo/results_*.zip C:\Users\YourName\Downloads\` |

> **Note:** Commands run on the server (Install Claude Code through Package
> results) are identical across all platforms — only the SSH/SCP commands on
> your local machine differ.

---

## Appendix A — Connecting with PuTTY (Windows)

If your Windows version does not include the built-in SSH client, use PuTTY.

### A.1 — Download and install PuTTY

1. Go to [https://www.putty.org/](https://www.putty.org/).
2. Download the **MSI installer** for Windows (64-bit).
3. Run the installer with default settings. This installs both **PuTTY** (the
   SSH client) and **PuTTYgen** (a key conversion tool).

### A.2 — Convert your `.pem` key to `.ppk` format

PuTTY uses its own key format (`.ppk`). If you downloaded a `.pem` file from
AWS, you need to convert it.

1. Open **PuTTYgen** (search for it in the Start menu).
2. Click **Load**.
3. In the file browser, change the file type filter from "PuTTY Private Key
   Files" to **All Files (*.*)**.
4. Navigate to your `.pem` file (e.g., `factor-zoo-key.pem`) and open it.
5. PuTTYgen will display "Successfully imported foreign key." Click **OK**.
6. Click **Save private key**. When prompted about saving without a passphrase,
   click **Yes** (for simplicity in this workflow).
7. Save the file as `factor-zoo-key.ppk` in the same folder.

### A.3 — Connect using PuTTY

1. Open **PuTTY**.
2. In the **Session** category:
   - **Host Name:** `ubuntu@54.201.83.112` (replace with your instance IP)
   - **Port:** `22`
   - **Connection type:** SSH
3. In the left panel, navigate to **Connection** → **SSH** → **Auth** →
   **Credentials**.
4. Under **Private key file for authentication**, click **Browse** and select
   your `.ppk` file.
5. (Optional) Return to the **Session** category, type a name under **Saved
   Sessions** (e.g., `factor-zoo`), and click **Save**. This lets you reload
   the configuration later without re-entering all the details.
6. Click **Open**.
7. If prompted about the server's host key, click **Accept**.

You are now connected. Continue from [Part 3](#part-3--install-and-authenticate-claude-code).

---

## Appendix B — Cost Estimation

A complete pipeline run (environment setup + replication) on `c7i.8xlarge`
typically costs under $3.00 in total:

| Component | Duration | Rate | Cost |
|-----------|----------|------|-----:|
| Environment setup (`/onboard`) | ~10 min | $1.43/hr | $0.24 |
| Pipeline run (`/replicate-paper`) | ~80 min | $1.43/hr | $1.91 |
| Storage (30 GB gp3, 2 hours) | — | $0.08/GB/mo | $0.01 |
| **Total** | **~90 min** | | **~$2.16** |

Data transfer out (downloading your results ZIP) is negligible for files under
1 GB.

To monitor your spending, visit the
[AWS Billing Dashboard](https://console.aws.amazon.com/billing/home).

---

*For the research pipeline itself, see the
[main README](README.md) and
[QUICKSTART.md](QUICKSTART.md).*
