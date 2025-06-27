# 🛰️ Pingman - Advanced Network Connectivity Tool (Bash)

A powerful, modular Bash-based utility to monitor network connectivity with real-time feedback, parallel execution, CSV/JSON exports, and verbose or quiet output options.  
This tool is perfect for system admins, network engineers, penetration testers, or anyone who needs a fast, scriptable alternative to graphical ping tools.

---

## 📦 Installation

### 🔗 Download

[⬇️ Download the latest `.deb` installer](https://github.com/sandeepyadav1122/Pingman/releases/tag/1.0.0)

> Make sure you're on a Debian-based system (Ubuntu/Kali/Pop!\_OS, etc.)

### 🛠️ Install via terminal:

```bash
sudo dpkg -i ping-checker_1.0.0_all.deb
````

### ✅ After installation, run it from anywhere using:

```bash
ping-checker [OPTIONS] [SITES...]
```

> 💡 If you're running the script directly without installing the `.deb`, use:
>
> ```bash
> ./ping_checker.sh [OPTIONS] [SITES...]
> ```

---

## 🔧 Features

* 🔁 **Parallel Execution** with controlled max jobs
* 🧮 **Packet Statistics**: packet loss, average time, and duration
* 📤 **Export Support**: Output results to CSV or JSON
* 🔍 **Verbose Mode**: See raw `ping` command output
* 🤫 **Quiet Mode**: Just the final summary
* 🗂️ **Batch Mode**: Read targets from a `.txt` file
* 🎯 **Input Validation**: Ensures only valid IPs or hostnames are pinged
* ⚡ **Color-coded UI** for easy result parsing

---

## 🖥️ Usage

```bash
ping-checker [OPTIONS] [SITES...]
```

### 📌 Options

| Option                   | Description                                  |
| ------------------------ | -------------------------------------------- |
| `-h`, `--help`           | Show help message                            |
| `-c`, `--count NUM`      | Number of ping attempts (default: 3)         |
| `-t`, `--timeout SEC`    | Timeout in seconds (default: 5)              |
| `-f`, `--file FILE`      | Read target sites from a file (one per line) |
| `-v`, `--verbose`        | Show full ping output                        |
| `-q`, `--quiet`          | Display only summary results                 |
| `-p`, `--parallel`       | Enable parallel ping execution               |
| `-j`, `--max-jobs NUM`   | Maximum parallel jobs (default: 10)          |
| `--csv FILE`             | Save output results in CSV format            |
| `--json FILE`            | Save output results in JSON format           |
| `--output-format FORMAT` | Set output format: `text`, `csv`, or `json`  |

---

## 🧪 Examples

### ✅ Basic Ping

```bash
ping-checker google.com github.com
```

### 🔁 Parallel Ping with Custom Job Limit

```bash
ping-checker -p -j 5 -c 4 8.8.8.8 cloudflare.com
```

### 📁 From File

```bash
ping-checker -f sites.txt
```

### 🧾 Export to CSV and JSON

```bash
ping-checker -p --csv results.csv --json results.json -f sites.txt
```

### 💻 Output as JSON to stdout

```bash
ping-checker --output-format json | jq .
```

---

## 🗃️ Sample `sites.txt`

```
# My target sites
google.com
github.com
8.8.8.8
1.1.1.1
```

---

## 🧠 Output Details

Each site's result includes:

* `site`: Hostname or IP being pinged
* `status`: `success` or `failed`
* `duration_seconds`: Total ping duration for the site
* `packet_loss_percent`: Percentage of lost packets
* `avg_ping_ms`: Average round-trip time

---

## 📊 Output Formats

### Text (default)

Standard human-readable colorized logs.

### CSV Output

```csv
timestamp,site,status,duration_seconds,packet_loss_percent,avg_ping_ms
2025-06-27 14:33:12,google.com,success,1.04,0,22.5
```

### JSON Output

```json
{
  "timestamp": "2025-06-27 14:33:12",
  "results": [
    {
      "site": "google.com",
      "status": "success",
      "duration_seconds": 1.04,
      "packet_loss_percent": 0,
      "avg_ping_ms": 22.5
    }
  ],
  "summary": {
    "total": 1,
    "successful": 1,
    "failed": 0
  }
}
```

---

## ⚙️ Dependencies

Only two basic requirements:

* `ping` – built-in for most systems
* `bc` – used for float calculation of time

### ✅ Install `bc` if missing

```bash
# Debian/Ubuntu
sudo apt install bc

# macOS (with Homebrew)
brew install bc
```

---

## 💡 Ideas for Future Features

| Feature              | Description                                 |
| -------------------- | ------------------------------------------- |
| 🧠 AI Auto-Retry     | Retry failed hosts with exponential backoff |
| 🌍 IP Geo Lookup     | Tag IPs with country/city info              |
| 🗓️ Cron Job Support | Turn this into a scheduled uptime monitor   |
| 📈 Integration       | Output to InfluxDB or Prometheus            |
| 📤 Alerting          | Send alerts to email or Telegram on failure |


