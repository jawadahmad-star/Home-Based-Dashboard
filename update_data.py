import pyreadstat
import re
import sys
from datetime import date

if len(sys.argv) < 2:
    print("ERROR: Dashboard path missing")
    sys.exit(1)

DASHBOARD = sys.argv[1]
HTML_FILE = DASHBOARD + r"\index.html"

print("Reading DTA files...")

h_df, _ = pyreadstat.read_dta(DASHBOARD + r"\Pak HBW Survey - Husband - Endline.dta")
w_df, _ = pyreadstat.read_dta(DASHBOARD + r"\Pak HBW Survey - Wife - Endline.dta")

print("Processing data...")

h = h_df[h_df['survey_status'] == 1].copy()
w = w_df[w_df['survey_status'] == 1].copy()

h = h.sort_values('submissiondate').groupby('hhd_id', as_index=False).last()
w = w.sort_values('submissiondate').groupby('hhd_id', as_index=False).last()

common = set(h['hhd_id']) & set(w['hhd_id'])
h = h[h['hhd_id'].isin(common)].copy()
w = w[w['hhd_id'].isin(common)].copy()
w = w.merge(h[['hhd_id','treat_label']], on='hhd_id', how='inner')

nW = len(w)
nH = len(h)
treat = int((h['treat_label'] == 'Treatment').sum())
ctrl = int((h['treat_label'] == 'Control').sum())

def cnt(df, col, val):
    return int((df[col] == val).sum())

def avg(df, col, positive=True):
    mask = df[col].notna() & (df[col] > 0) if positive else df[col].notna() & (df[col] >= 0)
    v = df.loc[mask, col]
    return round(float(v.mean()), 2) if len(v) else 0.0

# ... (baqi calculations same as pehle)

today = date.today().strftime('%B %#d, %Y')

new_data = f"""const DATA = {{
  lastUpdated: "{today}",
  nWives: {nW},
  nHusbands: {nH},
  treatment: {treat},
  control: {ctrl}
  // Note: Agar graphs nahi ban rahe to yahan aur variables add kar sakte hain
}};"""

with open(HTML_FILE, 'r', encoding='utf-8') as f:
    html = f.read()

pattern = r'const DATA = \{.*?\};'
new_html = re.sub(pattern, new_data, html, count=1, flags=re.DOTALL)

with open(HTML_FILE, 'w', encoding='utf-8') as f:
    f.write(new_html)

print(f"✅ SUCCESS: Updated {nW} wives, {nH} husbands on {today}")