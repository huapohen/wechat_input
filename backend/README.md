# WeType Clone Backend

Replacement for the unavailable WeChat Input cloud. The clients never contain
a model key; this service proxies DeepSeek and stores sync/transfer state.

## Run

```bash
python3 -m venv venv
venv/bin/pip install -r requirements.txt
export DEEPSEEK_API_KEY='...'
venv/bin/python app.py
```

Android emulator: `http://10.0.2.2:8787`; iOS simulator: `http://127.0.0.1:8787`;
physical devices: the Mac's LAN IP.

Local development may read `/Users/lwblx/Documents/ds_api` when
`DEEPSEEK_API_KEY` is absent. That file is outside the repository and is never
logged. Logs only show prefix + SHA-256 short fingerprint.

## Endpoints

See the report section 6.3 and `../reports/analysis.html`.
