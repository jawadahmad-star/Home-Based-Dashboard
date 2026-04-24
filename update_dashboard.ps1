# =============================================================
# HBW Dashboard Daily Update Script
# =============================================================
# HOW TO RUN (daily process):
#
#   STEP 1 — Export latest DTA files from SurveyCTO / Stata:
#             Place these two files in this DASHBOARD folder:
#               • Pak HBW Survey - Husband - Endline.dta
#               • Pak HBW Survey - Wife - Endline.dta
#
#   STEP 2 — Open PowerShell, navigate here, and run:
#               cd "D:\RS- Projects\Home-based Worker Follow Up Survey\DASHBOARD"
#               .\update_dashboard.ps1
#
#   STEP 3 — Script auto-updates index.html and pushes to GitHub.
#             Dashboard goes live at: https://homebased.rs.org.pk
#
# REQUIREMENTS: Python 3 + pyreadstat installed
#   Install once:  pip install pyreadstat
# =============================================================

param(
    [string]$DashboardDir = "D:\RS- Projects\Home-based Worker Follow Up Survey\DASHBOARD"
)

Set-Location $DashboardDir

Write-Host ""
Write-Host "=== HBW Dashboard Update Script ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
Write-Host ""

# ── Check DTA files exist
$husbDTA = "$DashboardDir\Pak HBW Survey - Husband - Endline.dta"
$wifeDTA = "$DashboardDir\Pak HBW Survey - Wife - Endline.dta"

if (-not (Test-Path $husbDTA)) { Write-Host "ERROR: Husband DTA not found: $husbDTA" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $wifeDTA)) { Write-Host "ERROR: Wife DTA not found:    $wifeDTA" -ForegroundColor Red; exit 1 }
Write-Host "DTA files found." -ForegroundColor Green

# ── Check Python + pyreadstat
try {
    $null = & python -c "import pyreadstat" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "pyreadstat not installed" }
    Write-Host "Python + pyreadstat OK." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python or pyreadstat not found." -ForegroundColor Red
    Write-Host "Fix:   pip install pyreadstat" -ForegroundColor Yellow
    exit 1
}

# ── Run Python to compute all stats and patch index.html
Write-Host ""
Write-Host "Reading DTA files and computing stats..." -ForegroundColor Yellow

$pythonScript = @'
import pyreadstat, re, sys
from datetime import date

DASHBOARD = sys.argv[1]
HTML_FILE = DASHBOARD + r"\index.html"

h_df, _ = pyreadstat.read_dta(DASHBOARD + r"\Pak HBW Survey - Husband - Endline.dta")
w_df, _ = pyreadstat.read_dta(DASHBOARD + r"\Pak HBW Survey - Wife - Endline.dta")

# Use all unique rows (all couple_ids are distinct in source data)
h = h_df.copy()
w = w_df.copy()
w = w.merge(h[['couple_id_entry','treat_label']], on='couple_id_entry', how='left')

nW = len(w)
nH = len(h)
treat = int((h['treat_label'] == 'Treatment').sum())
ctrl  = int((h['treat_label'] == 'Control').sum())

def cnt(df, col, val):
    return int((df[col] == val).sum())

def avg(df, col, positive=True):
    mask = df[col].notna() & (df[col] > 0) if positive else df[col].notna() & (df[col] >= 0)
    v = df.loc[mask, col]
    return round(float(v.mean()), 2) if len(v) else 0.0

def avgi(df, col):
    return int(round(avg(df, col), 0))

# Wife employment
wWorking        = cnt(w, 'current_work_status', 1)
wNotWorking     = cnt(w, 'current_work_status', 2)
wWorkDays       = round(avg(w, 'current_work_days'), 1)
wWorkHrs        = round(avg(w, 'current_work_hrs'), 1)
wStitching      = cnt(w, 'work_type_1', 1)
wOtherWork      = max(0, wWorking - wStitching)
wConsider       = cnt(w, 'consider_outside_12m', 1)
wDontConsider   = cnt(w, 'consider_outside_12m', 2)
wDiscussed      = cnt(w, 'discuss_husband_12m', 1)
wNeverDiscussed = cnt(w, 'discuss_husband_12m', 3)
hrSupport       = cnt(w, 'husband_reaction', 1)
hrOpen          = cnt(w, 'husband_reaction', 2)
hrAgainst       = cnt(w, 'husband_reaction', 4)
wConcernChores  = cnt(w, 'wife_concern_1', 1)
wConcernCare    = cnt(w, 'wife_concern_1', 2)
wConcernFamily  = cnt(w, 'wife_concern_1', 3)
wConcernSafety  = cnt(w, 'wife_concern_1', 5)

# Husband employment
hSectorApparel     = cnt(h, 'm_outside_work_type_1', 1)
hSectorMfg         = cnt(h, 'm_outside_work_type_2', 1)
hSectorTransport   = cnt(h, 'm_outside_work_type_3', 1)
hSectorHospitality = cnt(h, 'm_outside_work_type_5', 1) if 'm_outside_work_type_5' in h.columns else 0
hSectorConstruct   = cnt(h, 'm_outside_work_type_6', 1) if 'm_outside_work_type_6' in h.columns else 0
hWeeklyHrs         = round(avg(h, 'm_weekly_hours'), 1)
wStillWorking      = cnt(h, 'm_wife_work', 1)
wWorkSame          = cnt(h, 'work_w_change', 2)
wWorkWorse         = cnt(h, 'work_w_change', 3)
hConcernCare       = cnt(h, 'husband_concern_1', 2)
hConcernChores     = cnt(h, 'husband_concern_1', 1)
hConcernSafety     = cnt(h, 'husband_concern_1', 5)

# Earnings
wAvgEarnings = avgi(w, 'current_monthly_earnings')
hAvgEarnings = avgi(h, 'earnings_own')
wFactoryEst  = avgi(w, 'awareness_wage1')
hFactoryEst  = avgi(h, 'awareness_wage1')

hSh_wifeAll  = cnt(h, 'earnings_share', 5)
hSh_half     = cnt(h, 'earnings_share', 3)
hSh_husbMost = cnt(h, 'earnings_share', 2)
hSh_wifeMost = cnt(h, 'earnings_share', 4)
wSh_wifeAll  = cnt(w, 'earnings_share', 5)
wSh_half     = cnt(w, 'earnings_share', 3)
wSh_husbMost = cnt(w, 'earnings_share', 2)
wSh_husbAll  = cnt(w, 'earnings_share', 1)

# Household time
wOwnChores = round(avg(w, 'own_chores_hr', False), 2)
wOwnCare   = round(avg(w, 'own_care_hr',   False), 2)
hOwnChores = round(avg(h, 'own_chores_hr', False), 2)
hOwnCare   = round(avg(h, 'own_care_hr',   False), 2)
hHelpsWife = round(avg(h, 'sp_chores_hr',  False), 2)
wHelpsHusb = round(avg(w, 'sp_chores_hr',  False), 2) if 'sp_chores_hr' in w.columns else 0.0

# Mobility
tripWalk      = cnt(w, 'trip_how', 1)
tripRick      = cnt(w, 'trip_how', 2)
tripBus       = cnt(w, 'trip_how', 3)
tripAlone     = cnt(w, 'trip_company', 1)
tripFamily    = cnt(w, 'trip_company', 2)
tripColleague = cnt(w, 'trip_company', 4)
tripsPerWeek  = round(avg(w, 'n_trips', False), 2)

# Decision making
dmBase = nH
dmWJ  = [cnt(w,'decision_making_1',2), cnt(w,'decision_making_2',2), cnt(w,'decision_making_3',2)]
dmWHA = [cnt(w,'decision_making_1',3), cnt(w,'decision_making_2',3), cnt(w,'decision_making_3',3)]
dmHJ  = [cnt(h,'decision_making_1',2), cnt(h,'decision_making_2',2), cnt(h,'decision_making_3',2)]
dmHA  = [cnt(h,'decision_making_1',3), cnt(h,'decision_making_2',3), cnt(h,'decision_making_3',3)]

# Harassment
harH = {'never': cnt(h,'harassment',1), 'rare': cnt(h,'harassment',2), 'some': cnt(h,'harassment',3)}
harW = {'never': cnt(w,'harassment',1), 'rare': cnt(w,'harassment',2), 'some': cnt(w,'harassment',3)}

# Mental health & social desirability
mhW = [round(float(w[f'mh_{i}'].dropna().mean()), 2) for i in range(1,6)]
mhH = [round(float(h[f'mh_{i}'].dropna().mean()), 2) for i in range(1,6)]
sdW = [round(float(w[f'sd_{i}'].dropna().mean()), 2) for i in range(1,6)]
sdH = [round(float(h[f'sd_{i}'].dropna().mean()), 2) for i in range(1,6)]

# MH wife distribution (counts per response level 1-4)
mhWifeDist = [[int((w[f'mh_{i}']==v).sum()) for v in [1,2,3,4]] for i in range(1,6)]

# Interest form
wt = w[w['treat_label'] == 'Treatment']
wc = w[w['treat_label'] == 'Control']
tA = cnt(wt, 'form_1', 1); tD = cnt(wt, 'form_1', 2)
cA = cnt(wc, 'form_1', 1); cD = cnt(wc, 'form_1', 2)
noData = int(w['form_1'].isna().sum())

today = date.today().strftime('%B %#d, %Y')

# Build new DATA block
new_data = f"""const DATA = {{
  lastUpdated:    "{today}",

  // ── Sample
  nWives:         {nW},
  nHusbands:      {nH},
  treatment:      {treat},
  control:        {ctrl},

  // ── Wife employment
  wWorking:       {wWorking},
  wNotWorking:    {wNotWorking},
  wWorkDays:      {wWorkDays},
  wWorkHrs:       {wWorkHrs},
  wStitching:     {wStitching},
  wOtherWork:     {wOtherWork},
  wConsider:      {wConsider},
  wDontConsider:  {wDontConsider},
  wDiscussed:     {wDiscussed},
  wNeverDiscussed:{wNeverDiscussed},
  hrSupport:      {hrSupport},
  hrOpen:         {hrOpen},
  hrAgainst:      {hrAgainst},
  wConcernChores: {wConcernChores},
  wConcernCare:   {wConcernCare},
  wConcernFamily: {wConcernFamily},
  wConcernSafety: {wConcernSafety},

  // ── Husband employment
  hSectorApparel: {hSectorApparel},
  hSectorMfg:     {hSectorMfg},
  hSectorTransport:{hSectorTransport},
  hSectorHospitality:{hSectorHospitality},
  hSectorConstruct:{hSectorConstruct},
  hWeeklyHrs:     {hWeeklyHrs},
  wStillWorking:  {wStillWorking},
  wWorkSame:      {wWorkSame},
  wWorkWorse:     {wWorkWorse},
  hConcernCare:   {hConcernCare},
  hConcernChores: {hConcernChores},
  hConcernSafety: {hConcernSafety},

  // ── Earnings
  wAvgEarnings:   {wAvgEarnings},
  hAvgEarnings:   {hAvgEarnings},
  wFactoryEst:    {wFactoryEst},
  hFactoryEst:    {hFactoryEst},

  // Earnings share (husband view): 1=Husb all,2=Husb most,3=Half,4=Wife most,5=Wife all
  hShare: {{ wifeAll:{hSh_wifeAll}, half:{hSh_half}, husbMost:{hSh_husbMost}, wifeMost:{hSh_wifeMost} }},
  // Earnings share (wife view):    1=Husb all,2=Husb most,3=Half,5=Wife all
  wShare: {{ wifeAll:{wSh_wifeAll}, half:{wSh_half}, husbMost:{wSh_husbMost}, husbAll:{wSh_husbAll} }},

  // ── Household time (hrs/day)
  wOwnChores:     {wOwnChores},
  wOwnCare:       {wOwnCare},
  hOwnChores:     {hOwnChores},
  hOwnCare:       {hOwnCare},
  hHelpsWife:     {hHelpsWife},
  wHelpsHusb:     {wHelpsHusb},

  // ── Mobility
  tripWalk:       {tripWalk},
  tripRick:       {tripRick},
  tripBus:        {tripBus},
  tripAlone:      {tripAlone},
  tripFamily:     {tripFamily},
  tripColleague:  {tripColleague},
  tripsPerWeek:   {tripsPerWeek},

  // ── Decision making (count of "joint" responses, base n={dmBase} each)
  dmBase:         {dmBase},
  dmWifeJoint:    [{dmWJ[0]}, {dmWJ[1]}, {dmWJ[2]}],   // [health, purchases, visits]
  dmWifeHusbAlone:[{dmWHA[0]},  {dmWHA[1]},  {dmWHA[2]}],
  dmHusbJoint:    [{dmHJ[0]}, {dmHJ[1]}, {dmHJ[2]}],
  dmHusbAlone:    [{dmHA[0]},  {dmHA[1]},  {dmHA[2]}],

  // ── Harassment
  harHusb: {{ never:{harH['never']}, rare:{harH['rare']}, some:{harH['some']} }},
  harWife: {{ never:{harW['never']}, rare:{harW['rare']}, some:{harW['some']}  }},

  // ── Mental health means (1=Not at all, 4=Nearly every day)
  mhWife: [{mhW[0]}, {mhW[1]}, {mhW[2]}, {mhW[3]}, {mhW[4]}],
  mhHusb: [{mhH[0]}, {mhH[1]}, {mhH[2]}, {mhH[3]}, {mhH[4]}],

  // ── Social desirability means (1=True, 2=False)
  sdWife: [{sdW[0]}, {sdW[1]}, {sdW[2]}, {sdW[3]}, {sdW[4]}],
  sdHusb: [{sdH[0]}, {sdH[1]}, {sdH[2]}, {sdH[3]}, {sdH[4]}],

  // ── Wife MH distribution (counts per level 1-4 for each of mh_1...mh_5)
  mhWifeDist: [
    [{mhWifeDist[0][0]}, {mhWifeDist[0][1]}, {mhWifeDist[0][2]}, {mhWifeDist[0][3]}],  // mh_1
    [{mhWifeDist[1][0]}, {mhWifeDist[1][1]}, {mhWifeDist[1][2]}, {mhWifeDist[1][3]}],  // mh_2
    [{mhWifeDist[2][0]}, {mhWifeDist[2][1]}, {mhWifeDist[2][2]}, {mhWifeDist[2][3]}],  // mh_3
    [{mhWifeDist[3][0]}, {mhWifeDist[3][1]}, {mhWifeDist[3][2]}, {mhWifeDist[3][3]}],  // mh_4
    [{mhWifeDist[4][0]}, {mhWifeDist[4][1]}, {mhWifeDist[4][2]}, {mhWifeDist[4][3]}]   // mh_5
  ],

  // ── Interest Form (factory job expression of interest, wife survey)
  interestForm: {{
    treatAgree:   {tA},  ctrlAgree:   {cA},
    treatDecline: {tD},  ctrlDecline: {cD},
    treatTotal:   {tA+tD}, ctrlTotal: {cA+cD},
    noData:       {noData}
  }}
}};"""

# Read index.html and replace the DATA block
with open(HTML_FILE, 'r', encoding='utf-8') as f:
    html = f.read()

# Replace between "const DATA = {" and "};" (the first one after const DATA)
pattern = r'const DATA = \{.*?\};'
new_html = re.sub(pattern, new_data, html, count=1, flags=re.DOTALL)

if new_html == html:
    print("ERROR: Could not find const DATA block in index.html", flush=True)
    sys.exit(1)

with open(HTML_FILE, 'w', encoding='utf-8') as f:
    f.write(new_html)

print(f"OK: {nW} wives, {nH} husbands | Treatment={treat} Control={ctrl}", flush=True)
print(f"OK: Wife earn=PKR{wAvgEarnings} | Husb earn=PKR{hAvgEarnings}", flush=True)
print(f"OK: Working wives={wWorking} | Still working (husb report)={wStillWorking}", flush=True)
print(f"OK: index.html updated — {today}", flush=True)
'@

$result = python -c $pythonScript $DashboardDir 2>&1
$result | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Python script failed. index.html NOT updated." -ForegroundColor Red
    exit 1
}

# ── Git commit and push
Write-Host ""
Write-Host "Committing and pushing to GitHub..." -ForegroundColor Yellow

$today = Get-Date -Format 'yyyy-MM-dd'
git -C $DashboardDir add index.html
git -C $DashboardDir commit -m "Daily update: $today — stats refreshed from DTA files"
git -C $DashboardDir push origin main

Write-Host ""
Write-Host "Done! Dashboard live at: https://homebased.rs.org.pk" -ForegroundColor Cyan
