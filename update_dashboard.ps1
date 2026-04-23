# HBW Dashboard Daily Update Script
# Run this after uploading new CSV files to regenerate stats and push to GitHub
# Schedule via Windows Task Scheduler for daily auto-update

param(
    [string]$HusbandCSV = "D:\RS- Projects\Home-based Worker Follow Up Survey\Husband Survey Follow-up\Data\Pak HBW Survey - Husband - Endline_WIDE.csv",
    [string]$WifeCSV    = "D:\RS- Projects\Home-based Worker Follow Up Survey\Wife Survey Follow-up\Data\Pak HBW Survey - Wife - Endline_WIDE.csv",
    [string]$DashboardDir = "D:\RS- Projects\Home-based Worker Follow Up Survey\DASHBOARD"
)

Set-Location $DashboardDir

Write-Host "=== HBW Dashboard Update Script ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray

# ── Read Data
try {
    $h = Import-Csv $HusbandCSV -ErrorAction Stop
    $w = Import-Csv $WifeCSV    -ErrorAction Stop
    Write-Host "Data loaded: $($h.Count) husbands, $($w.Count) wives" -ForegroundColor Green
} catch {
    Write-Host "ERROR reading CSV files: $_" -ForegroundColor Red
    exit 1
}

# ── Compute Stats
$nH       = $h.Count
$nW       = $w.Count
$treat    = ($h | Where-Object {$_.treat_label -eq 'Treatment'}).Count
$ctrl     = ($h | Where-Object {$_.treat_label -eq 'Control'}).Count

$wWorking = ($w | Where-Object {$_.current_work_status -eq '1'}).Count
$wNotWork = ($w | Where-Object {$_.current_work_status -eq '2'}).Count

$wEarns   = $w | Where-Object {$_.current_monthly_earnings -match '^\d'} | ForEach-Object { [double]$_.current_monthly_earnings }
$wAvgEarn = if ($wEarns.Count -gt 0) { [math]::Round(($wEarns | Measure-Object -Average).Average, 0) } else { 0 }

$hEarns   = $h | Where-Object {$_.earnings_own -match '^\d'} | ForEach-Object { [double]$_.earnings_own }
$hAvgEarn = if ($hEarns.Count -gt 0) { [math]::Round(($hEarns | Measure-Object -Average).Average, 0) } else { 0 }

$hWifeWork = ($h | Where-Object {$_.m_wife_work -eq '1'}).Count
$wConsider = ($w | Where-Object {$_.consider_outside_12m -eq '1'}).Count
$wDiscuss  = ($w | Where-Object {$_.discuss_husband_12m -eq '1'}).Count

# Wife chores
$wOCh = ($w | Where-Object {$_.own_chores_hr -match '^\d'} | ForEach-Object { [double]$_.own_chores_hr } | Measure-Object -Average).Average
$wOCr = ($w | Where-Object {$_.own_care_hr -match '^\d'} | ForEach-Object { [double]$_.own_care_hr } | Measure-Object -Average).Average
$hOCh = ($h | Where-Object {$_.own_chores_hr -match '^\d'} | ForEach-Object { [double]$_.own_chores_hr } | Measure-Object -Average).Average
$hSpCh = ($h | Where-Object {$_.sp_chores_hr -match '^\d'} | ForEach-Object { [double]$_.sp_chores_hr } | Measure-Object -Average).Average

$wOChR  = [math]::Round($wOCh, 2)
$wOCrR  = [math]::Round($wOCr, 2)
$hOChR  = [math]::Round($hOCh, 2)
$hSpChR = [math]::Round($hSpCh, 2)

# Mental health avgs
$mhVarsW = @{}; $mhVarsH = @{}
foreach ($i in 1..5) {
    $valsW = $w | Where-Object {$_."mh_$i" -match '^\d'} | ForEach-Object { [double]$_."mh_$i" }
    $valsH = $h | Where-Object {$_."mh_$i" -match '^\d'} | ForEach-Object { [double]$_."mh_$i" }
    $mhVarsW["mh_$i"] = if ($valsW.Count -gt 0) { [math]::Round(($valsW | Measure-Object -Average).Average, 2) } else { 0 }
    $mhVarsH["mh_$i"] = if ($valsH.Count -gt 0) { [math]::Round(($valsH | Measure-Object -Average).Average, 2) } else { 0 }
}

# Wage awareness
$wAw1 = ($w | Where-Object {$_.awareness_wage1 -match '^\d'} | ForEach-Object { [double]$_.awareness_wage1 } | Measure-Object -Average).Average
$wAw1R = if ($wAw1) { [math]::Round($wAw1, 0) } else { 0 }

# Work days/hours
$wDays = ($w | Where-Object {$_.current_work_days -match '^\d'} | ForEach-Object { [double]$_.current_work_days } | Measure-Object -Average).Average
$wHrs  = ($w | Where-Object {$_.current_work_hrs  -match '^\d'} | ForEach-Object { [double]$_.current_work_hrs  } | Measure-Object -Average).Average
$wDaysR = if ($wDays) { [math]::Round($wDays, 1) } else { 0 }
$wHrsR  = if ($wHrs)  { [math]::Round($wHrs,  1) } else { 0 }

# Decision making
$dm_w = @{}; $dm_h = @{}
foreach ($d in 1..3) {
    $dm_w["d$d"] = ($w | Where-Object {$_."decision_making_$d" -eq '2'}).Count
    $dm_h["d$d"] = ($h | Where-Object {$_."decision_making_$d" -eq '2'}).Count
}

# Harassment
$harH = @{
    never  = ($h | Where-Object {$_.harassment -eq '1'}).Count
    rare   = ($h | Where-Object {$_.harassment -eq '2'}).Count
    some   = ($h | Where-Object {$_.harassment -eq '3'}).Count
}
$harW = @{
    never  = ($w | Where-Object {$_.harassment -eq '1'}).Count
    rare   = ($w | Where-Object {$_.harassment -eq '2'}).Count
    some   = ($w | Where-Object {$_.harassment -eq '3'}).Count
}

# Work sectors (husband)
$sec1 = ($h | Where-Object {$_.m_outside_work_type_1 -eq '1'}).Count
$sec2 = ($h | Where-Object {$_.m_outside_work_type_2 -eq '1'}).Count
$sec3 = ($h | Where-Object {$_.m_outside_work_type_3 -eq '1'}).Count
$sec5 = ($h | Where-Object {$_.m_outside_work_type_5 -eq '1'}).Count
$sec6 = ($h | Where-Object {$_.m_outside_work_type_6 -eq '1'}).Count

# Husband weekly hours
$hWkHrs = ($h | Where-Object {$_.m_weekly_hours -match '^\d'} | ForEach-Object { [double]$_.m_weekly_hours } | Measure-Object -Average).Average
$hWkHrsR = if ($hWkHrs) { [math]::Round($hWkHrs, 1) } else { 0 }

# Wife still working (husband report)
$wStillWork = ($h | Where-Object {$_.m_wife_work -eq '1'}).Count
$wWorkPct   = if ($nH -gt 0) { [math]::Round($wStillWork * 100 / $nH, 0) } else { 0 }

# Work change
$wChSame  = ($h | Where-Object {$_.work_w_change -eq '2'}).Count
$wChWorse = ($h | Where-Object {$_.work_w_change -eq '3'}).Count

# Earnings share
$hSh5 = ($h | Where-Object {$_.earnings_share -eq '5'}).Count
$hSh3 = ($h | Where-Object {$_.earnings_share -eq '3'}).Count
$hSh2 = ($h | Where-Object {$_.earnings_share -eq '2'}).Count
$hSh4 = ($h | Where-Object {$_.earnings_share -eq '4'}).Count
$wSh5 = ($w | Where-Object {$_.earnings_share -eq '5'}).Count
$wSh3 = ($w | Where-Object {$_.earnings_share -eq '3'}).Count
$wSh2 = ($w | Where-Object {$_.earnings_share -eq '2'}).Count
$wSh1 = ($w | Where-Object {$_.earnings_share -eq '1'}).Count

# Trip data
$tripWalk = ($w | Where-Object {$_.trip_how -eq '1'}).Count
$tripRick = ($w | Where-Object {$_.trip_how -eq '2'}).Count
$tripBus  = ($w | Where-Object {$_.trip_how -eq '3'}).Count
$tripAlone = ($w | Where-Object {$_.trip_company -eq '1'}).Count
$tripFam   = ($w | Where-Object {$_.trip_company -eq '2'}).Count
$tripColl  = ($w | Where-Object {$_.trip_company -eq '4'}).Count
$tripAvg = ($w | Where-Object {$_.n_trips -match '^\d'} | ForEach-Object { [double]$_.n_trips } | Measure-Object -Average).Average
$tripAvgR = if ($tripAvg) { [math]::Round($tripAvg, 2) } else { 0 }

# Husband concerns
$hCon1 = ($h | Where-Object {$_.husband_concern_1 -eq '1'}).Count
$hCon2 = ($h | Where-Object {$_.husband_concern_1 -eq '2'}).Count
$hCon5 = ($h | Where-Object {$_.husband_concern_1 -eq '5'}).Count

# Wife concerns
$wCon1 = ($w | Where-Object {$_.wife_concern_1 -eq '1'}).Count
$wCon2 = ($w | Where-Object {$_.wife_concern_1 -eq '2'}).Count
$wCon3 = ($w | Where-Object {$_.wife_concern_1 -eq '3'}).Count
$wCon5 = ($w | Where-Object {$_.wife_concern_1 -eq '5'}).Count

# Husband reaction to discussion
$hrSup  = ($w | Where-Object {$_.husband_reaction -eq '1'}).Count
$hrOpen = ($w | Where-Object {$_.husband_reaction -eq '2'}).Count
$hrAgst = ($w | Where-Object {$_.husband_reaction -eq '4'}).Count

$wWorkPctOfWith = if (($wWorking + $wNotWork) -gt 0) { [math]::Round($wWorking * 100 / ($wWorking + $wNotWork), 0) } else { 0 }
$considerPct = if (($wConsider + ($w | Where-Object {$_.consider_outside_12m -eq '2'}).Count) -gt 0) { [math]::Round($wConsider * 100 / ($wConsider + ($w | Where-Object {$_.consider_outside_12m -eq '2'}).Count), 0) } else { 0 }

$today = Get-Date -Format 'MMMM d, yyyy'
$hHarassPct = if ($nH -gt 0) { [math]::Round($harH.some * 100 / $nH, 0) } else { 0 }

Write-Host "`nKEY STATS:" -ForegroundColor Yellow
Write-Host "  Wives: $nW | Husbands: $nH | Treatment: $treat | Control: $ctrl"
Write-Host "  Wife avg earnings: PKR $wAvgEarn | Husband avg: PKR $hAvgEarn"
Write-Host "  Working wives: $wWorking | Wife work (husband report): $wStillWork"
Write-Host "  Work days: $wDaysR | Work hrs: $wHrsR"

# ── Read current index.html
$html = Get-Content "$DashboardDir\index.html" -Raw

# ── Update KPI values using regex replacements for data-driven values
# Update the "last updated" date in footer
$html = $html -replace 'Data collected [A-Za-z]+ \d{4}', "Data collected $today"

# Update main KPI numbers in header pill
$html = $html -replace '\d+ Wives · \d+ Husbands · Endline', "$nW Wives · $nH Husbands · Endline"

# ── Update JavaScript chart data
$jsBlock = @"
// ── OVERVIEW: Composition Doughnut
new Chart(document.getElementById('chartComposition'), {
  type: 'doughnut',
  data: {
    labels: ['Wives Surveyed', 'Husbands Surveyed'],
    datasets: [{ data: [$nW, $nH], backgroundColor: [RED, NAVY], borderWidth: 0 }]
  },
  options: {
    plugins: {
      legend: { position: 'bottom', labels: { font: { family: 'Inter', size: 12 } } },
      datalabels: {
        display: true, color: '#fff', font: { family: 'Inter', size: 14, weight: '700' },
        formatter: (v) => v
      }
    }
  }
});

// ── OVERVIEW: Treatment/Control
new Chart(document.getElementById('chartTreatment'), {
  type: 'bar',
  data: {
    labels: ['Treatment', 'Control'],
    datasets: [{ label: 'Husbands', data: [$treat, $ctrl], backgroundColor: [TEAL, NAVY], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font: { family:'Inter', size:14, weight:'700' }, anchor:'center', align:'center' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: 10, ticks: { stepSize: 2, font:{family:'Inter',size:11}, color:'#475569' } } }
  }
});

// ── OVERVIEW: Work Status
new Chart(document.getElementById('chartWorkStatus'), {
  type: 'doughnut',
  data: {
    labels: ['Currently Working', 'Not Working'],
    datasets: [{ data: [$wWorking, $wNotWork], backgroundColor: [TEAL, RED], borderWidth: 0 }]
  },
  options: {
    plugins: {
      legend: { position: 'bottom', labels: { font: { family: 'Inter', size: 11 } } },
      datalabels: { display: true, color: '#fff', font: { family: 'Inter', size: 13, weight: '700' }, formatter: v => v }
    }
  }
});

// ── OVERVIEW: Earnings Comparison
new Chart(document.getElementById('chartEarningsOverview'), {
  type: 'bar',
  data: {
    labels: ['Wife (Home)', 'Husband (Outside)'],
    datasets: [{ data: [$wAvgEarn, $hAvgEarn], backgroundColor: [RED, NAVY], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font: { family:'Inter', size:11, weight:'700' },
        anchor:'center', align:'center', formatter: v => 'PKR '+v.toLocaleString() }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, ticks: { font:{family:'Inter',size:11}, color:'#475569', callback: v => 'PKR '+v.toLocaleString() } } }
  }
});

// ── OVERVIEW: Harassment Overview
new Chart(document.getElementById('chartHarassOverview'), {
  type: 'bar',
  data: {
    labels: ['Never', 'Rare', 'Somewhat\nCommon', 'Very\nCommon'],
    datasets: [
      { label: 'Husbands', data: [$($harH.never), $($harH.rare), $($harH.some), 0], backgroundColor: NAVY, borderRadius: 6 },
      { label: 'Wives', data: [$($harW.never), $($harW.rare), $($harW.some), 0], backgroundColor: RED, borderRadius: 6 }
    ]
  },
  options: {
    ...defaults,
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: $([math]::Max($nH,$nW)+2), ticks: { stepSize: 2, font:{family:'Inter',size:11}, color:'#475569' } } }
  }
});

// ── WIFE: Status
new Chart(document.getElementById('chartWifeStatus'), {
  type: 'bar',
  data: {
    labels: ['Currently Working', 'Not Working'],
    datasets: [{ data: [$wWorking, $wNotWork], backgroundColor: [TEAL, RED], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:14,weight:'700'}, anchor:'center', align:'center' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: $([math]::Max($wWorking,$wNotWork)+3), ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── WIFE: Consider Outside
new Chart(document.getElementById('chartConsiderOutside'), {
  type: 'bar',
  data: {
    labels: ['Considered Outside Work', 'Did Not Consider'],
    datasets: [{ data: [$wConsider, $(($w | Where-Object {$_.consider_outside_12m -eq '2'}).Count)], backgroundColor: [PURPLE, NAVY], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:14,weight:'700'}, anchor:'center', align:'center' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: 14, ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── WIFE: Discuss Husband
new Chart(document.getElementById('chartDiscussHusband'), {
  type: 'bar',
  data: {
    labels: ['Yes, Once', 'No, Never'],
    datasets: [{ data: [$wDiscuss, $(($w | Where-Object {$_.discuss_husband_12m -eq '3'}).Count)], backgroundColor: [TEAL, RED], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:14,weight:'700'}, anchor:'center', align:'center' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: 12, ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── WIFE: Husband Reaction
new Chart(document.getElementById('chartHusbandReaction'), {
  type: 'bar',
  data: {
    labels: ['Supportive', 'Open / Needs Time', 'Very Against'],
    datasets: [{ data: [$hrSup, $hrOpen, $hrAgst], backgroundColor: [TEAL, AMBER, RED], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:14,weight:'700'}, anchor:'center', align:'center' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: 4, ticks:{stepSize:1,font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── WIFE: Concerns
new Chart(document.getElementById('chartWifeConcerns'), {
  type: 'bar',
  data: {
    labels: ['Household\nChores', 'Childcare', 'Family\nOpinion', 'Safety /\nTravel'],
    datasets: [{ data: [$wCon1, $wCon2, $wCon3, $wCon5], backgroundColor: [RED, AMBER, NAVY, PURPLE], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:13,weight:'700'}, anchor:'center', align:'center' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: $([math]::Max($wCon1,$wCon2)+3), ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── HUSBAND: Sector
new Chart(document.getElementById('chartHusbandSector'), {
  type: 'bar',
  data: {
    labels: ['Apparel / Garment', 'Other Manufacturing', 'Transportation', 'Hospitality', 'Construction'],
    datasets: [{ data: [$sec1, $sec2, $sec5, $sec6, $sec3], backgroundColor: [NAVY, TEAL, AMBER, PURPLE, RED], borderRadius: 8 }]
  },
  options: {
    indexAxis: 'y',
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:12,weight:'700'}, anchor:'end', align:'left' }
    },
    scales: {
      x: { ...defaults.scales.x, max: $([math]::Max($sec1,$sec2)+3), ticks:{font:{family:'Inter',size:11},color:'#475569'} },
      y: { ticks: { font:{family:'Inter',size:11}, color:'#475569' }, grid:{display:false} }
    }
  }
});

// ── HUSBAND: Work Change
new Chart(document.getElementById('chartWorkChange'), {
  type: 'doughnut',
  data: {
    labels: ['Same as 12m Ago', 'Worse than 12m Ago'],
    datasets: [{ data: [$wChSame, $wChWorse], backgroundColor: [AMBER, RED], borderWidth: 0 }]
  },
  options: {
    plugins: {
      legend: { position: 'bottom', labels: { font: { family: 'Inter', size: 12 } } },
      datalabels: { display: true, color: '#fff', font: { family: 'Inter', size: 13, weight: '700' }, formatter: v => v }
    }
  }
});

// ── HUSBAND: Concerns
new Chart(document.getElementById('chartHusbandConcerns'), {
  type: 'bar',
  data: {
    labels: ['Childcare', 'Household\nChores', 'Safety /\nTravel'],
    datasets: [{ data: [$hCon2, $hCon1, $hCon5], backgroundColor: [RED, AMBER, NAVY], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:14,weight:'700'}, anchor:'center', align:'center' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: $([math]::Max($hCon1,$hCon2)+3), ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── HUSBAND: Harassment
new Chart(document.getElementById('chartHusbandHarass'), {
  type: 'bar',
  data: {
    labels: ['Never Happens', 'Rare', 'Somewhat Common', 'Very Common'],
    datasets: [{ data: [$($harH.never), $($harH.rare), $($harH.some), 0], backgroundColor: [TEAL, AMBER, RED, NAVY], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:13,weight:'700'}, anchor:'center', align:'center' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: $($nH+2), ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── EARNINGS: Bar Comparison
new Chart(document.getElementById('chartEarningsBar'), {
  type: 'bar',
  data: {
    labels: ['Wife (Home-Based)', 'Husband (Outside)'],
    datasets: [{ data: [$wAvgEarn, $hAvgEarn], backgroundColor: [RED, NAVY], borderRadius: 10 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:11,weight:'700'},
        anchor:'center', align:'center', formatter: v => 'PKR\n'+v.toLocaleString() }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, ticks:{ font:{family:'Inter',size:11}, color:'#475569', callback: v => 'PKR '+v.toLocaleString() } } }
  }
});

// ── EARNINGS: Wage Awareness
new Chart(document.getElementById('chartWageAwareness'), {
  type: 'bar',
  data: {
    labels: ['Wife Actual\n(Home Work)', "Wife's Estimate\n(Factory Wage)", "Husband's Estimate\n(Factory Wage)"],
    datasets: [{ data: [$wAvgEarn, $wAw1R, $([math]::Round(($h | Where-Object {$_.awareness_wage1 -match '^\d'} | ForEach-Object { [double]$_.awareness_wage1 } | Measure-Object -Average).Average, 0))], backgroundColor: [RED, TEAL, NAVY], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:10,weight:'700'},
        anchor:'center', align:'center', formatter: v => 'PKR\n'+v.toLocaleString() }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, ticks:{ font:{family:'Inter',size:11},color:'#475569', callback: v=>'PKR '+v.toLocaleString() } } }
  }
});

// ── EARNINGS: Share Husband
new Chart(document.getElementById('chartShareHusband'), {
  type: 'doughnut',
  data: {
    labels: ['Wife Keeps All', 'Wife Keeps Half', 'Husband Gets Most', 'Wife Keeps Most'],
    datasets: [{ data: [$hSh5, $hSh3, $hSh2, $hSh4], backgroundColor: [TEAL, AMBER, RED, PURPLE], borderWidth: 0 }]
  },
  options: {
    plugins: {
      legend: { position: 'bottom', labels: { font: { family: 'Inter', size: 11 } } },
      datalabels: { display: true, color: '#fff', font: { family: 'Inter', size: 12, weight: '700' }, formatter: v => v }
    }
  }
});

// ── EARNINGS: Share Wife
new Chart(document.getElementById('chartShareWife'), {
  type: 'doughnut',
  data: {
    labels: ['Wife Keeps All', 'Husband Gets Half', 'Husband Gets Most', 'Husband Gets All'],
    datasets: [{ data: [$wSh5, $wSh3, $wSh2, $wSh1], backgroundColor: [TEAL, AMBER, RED, NAVY], borderWidth: 0 }]
  },
  options: {
    plugins: {
      legend: { position: 'bottom', labels: { font: { family: 'Inter', size: 11 } } },
      datalabels: { display: true, color: '#fff', font: { family: 'Inter', size: 12, weight: '700' }, formatter: v => v }
    }
  }
});

// ── HOUSEHOLD: Time Use
new Chart(document.getElementById('chartTimeUse'), {
  type: 'bar',
  data: {
    labels: ['Household Chores', 'Caregiving'],
    datasets: [
      { label: 'Wife (own)', data: [$wOChR, $wOCrR], backgroundColor: RED, borderRadius: 6 },
      { label: 'Husband (own)', data: [$hOChR, $([math]::Round(($h | Where-Object {$_.own_care_hr -match '^\d'} | ForEach-Object { [double]$_.own_care_hr } | Measure-Object -Average).Average, 2))], backgroundColor: NAVY, borderRadius: 6 }
    ]
  },
  options: {
    ...defaults,
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: 5, ticks:{font:{family:'Inter',size:11},color:'#475569'}, title:{display:true,text:'Hours per Day',font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── HOUSEHOLD: Spouse Help
new Chart(document.getElementById('chartSpouseHelp'), {
  type: 'bar',
  data: {
    labels: ['Husband helps\nwife w/ chores', 'Wife helps\nhusband w/ chores'],
    datasets: [{ data: [$hSpChR, $([math]::Round(($h | Where-Object {$_.sp_chores_hr -match '^\d'} | ForEach-Object { [double]$_.sp_chores_hr } | Measure-Object -Average).Average, 2))], backgroundColor: [NAVY, RED], borderRadius: 8 }]
  },
  options: {
    ...defaults,
    plugins: { ...defaults.plugins, legend: { display: false },
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:12,weight:'700'}, anchor:'center', align:'center', formatter: v => v+'h' }
    },
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: 3, ticks:{font:{family:'Inter',size:11},color:'#475569'}, title:{display:true,text:'Hours per Day',font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── HOUSEHOLD: Trip Mode
new Chart(document.getElementById('chartTripHow'), {
  type: 'doughnut',
  data: {
    labels: ['Walk', 'Rickshaw', 'Bus'],
    datasets: [{ data: [$tripWalk, $tripRick, $tripBus], backgroundColor: [TEAL, AMBER, NAVY], borderWidth: 0 }]
  },
  options: {
    plugins: {
      legend: { position: 'bottom', labels: { font: { family: 'Inter', size: 12 } } },
      datalabels: { display: true, color: '#fff', font: { family: 'Inter', size: 13, weight: '700' }, formatter: v => v }
    }
  }
});

// ── HOUSEHOLD: Trip Company
new Chart(document.getElementById('chartTripCompany'), {
  type: 'doughnut',
  data: {
    labels: ['Alone', 'With Family', 'With Colleague'],
    datasets: [{ data: [$tripAlone, $tripFam, $tripColl], backgroundColor: [RED, NAVY, TEAL], borderWidth: 0 }]
  },
  options: {
    plugins: {
      legend: { position: 'bottom', labels: { font: { family: 'Inter', size: 12 } } },
      datalabels: { display: true, color: '#fff', font: { family: 'Inter', size: 13, weight: '700' }, formatter: v => v }
    }
  }
});

// ── DECISIONS: Wife
new Chart(document.getElementById('chartDecisionWife'), {
  type: 'bar',
  data: {
    labels: ['Healthcare', 'Large\nPurchases', 'Family\nVisits'],
    datasets: [
      { label: 'Joint (Wife+Husband)', data: [$($dm_w.d1), $($dm_w.d2), $($dm_w.d3)], backgroundColor: TEAL, borderRadius: 6 },
      { label: 'Husband Alone', data: [$(($w | Where-Object {$_.decision_making_1 -eq '3'}).Count), $(($w | Where-Object {$_.decision_making_2 -eq '3'}).Count), $(($w | Where-Object {$_.decision_making_3 -eq '3'}).Count)], backgroundColor: RED, borderRadius: 6 }
    ]
  },
  options: {
    ...defaults,
    scales: { ...defaults.scales,
      x: { ...defaults.scales.x, stacked: true },
      y: { ...defaults.scales.y, stacked: true, max: 16, ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} }
    },
    plugins: { ...defaults.plugins,
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:11,weight:'700'}, formatter: v => v > 0 ? v : '' }
    }
  }
});

// ── DECISIONS: Husband
new Chart(document.getElementById('chartDecisionHusband'), {
  type: 'bar',
  data: {
    labels: ['Healthcare', 'Large\nPurchases', 'Family\nVisits'],
    datasets: [
      { label: 'Joint (Wife+Husband)', data: [$($dm_h.d1), $($dm_h.d2), $($dm_h.d3)], backgroundColor: NAVY, borderRadius: 6 },
      { label: 'Husband Alone', data: [$(($h | Where-Object {$_.decision_making_1 -eq '3'}).Count), $(($h | Where-Object {$_.decision_making_2 -eq '3'}).Count), $(($h | Where-Object {$_.decision_making_3 -eq '3'}).Count)], backgroundColor: RED, borderRadius: 6 }
    ]
  },
  options: {
    ...defaults,
    scales: { ...defaults.scales,
      x: { ...defaults.scales.x, stacked: true },
      y: { ...defaults.scales.y, stacked: true, max: 16, ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} }
    },
    plugins: { ...defaults.plugins,
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:11,weight:'700'}, formatter: v => v > 0 ? v : '' }
    }
  }
});

// ── DECISIONS: Cross Compare
$jdW1 = if ($($dm_w.d1) -gt 0 -and $nH -gt 0) { [math]::Round($($dm_w.d1)*100/14,0) } else { 0 }
$jdW2 = if ($($dm_w.d2) -gt 0 -and $nH -gt 0) { [math]::Round($($dm_w.d2)*100/14,0) } else { 0 }
$jdW3 = if ($($dm_w.d3) -gt 0 -and $nH -gt 0) { [math]::Round($($dm_w.d3)*100/14,0) } else { 0 }
$jdH1 = if ($($dm_h.d1) -gt 0 -and $nH -gt 0) { [math]::Round($($dm_h.d1)*100/$nH,0) } else { 0 }
$jdH2 = if ($($dm_h.d2) -gt 0 -and $nH -gt 0) { [math]::Round($($dm_h.d2)*100/$nH,0) } else { 0 }
$jdH3 = if ($($dm_h.d3) -gt 0 -and $nH -gt 0) { [math]::Round($($dm_h.d3)*100/$nH,0) } else { 0 }
new Chart(document.getElementById('chartDecisionCompare'), {
  type: 'bar',
  data: {
    labels: ['Healthcare', 'Large Purchases', 'Family Visits'],
    datasets: [
      { label: 'Wife reports Joint (%)', data: [$jdW1, $jdW2, $jdW3], backgroundColor: RED, borderRadius: 6 },
      { label: 'Husband reports Joint (%)', data: [$jdH1, $jdH2, $jdH3], backgroundColor: NAVY, borderRadius: 6 }
    ]
  },
  options: {
    ...defaults,
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: 110, ticks:{font:{family:'Inter',size:11},color:'#475569', callback: v=>v+'%'} } },
    plugins: { ...defaults.plugins,
      datalabels: { display: true, color: '#fff', font:{family:'Inter',size:12,weight:'700'}, anchor:'center', align:'center', formatter: v=>v+'%' }
    }
  }
});

// ── WELLBEING: Mental Health
new Chart(document.getElementById('chartMentalHealth'), {
  type: 'bar',
  data: {
    labels: ['mh_1\nLittle Interest', 'mh_2\nFeeling Down', 'mh_3\nTired/Fatigue', 'mh_4\nFeeling Happy', 'mh_5\nSatisfied'],
    datasets: [
      { label: 'Wife', data: [$($mhVarsW['mh_1']), $($mhVarsW['mh_2']), $($mhVarsW['mh_3']), $($mhVarsW['mh_4']), $($mhVarsW['mh_5'])], backgroundColor: RED, borderRadius: 6 },
      { label: 'Husband', data: [$($mhVarsH['mh_1']), $($mhVarsH['mh_2']), $($mhVarsH['mh_3']), $($mhVarsH['mh_4']), $($mhVarsH['mh_5'])], backgroundColor: NAVY, borderRadius: 6 }
    ]
  },
  options: {
    ...defaults,
    scales: { ...defaults.scales, y: { ...defaults.scales.y, min: 0, max: 4.5, ticks:{font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── WELLBEING: Social Desirability
$sd = @{}
foreach ($i in 1..5) {
  $vW = ($w | Where-Object {$_."sd_$i" -match '^\d'} | ForEach-Object { [double]$_."sd_$i" } | Measure-Object -Average).Average
  $vH = ($h | Where-Object {$_."sd_$i" -match '^\d'} | ForEach-Object { [double]$_."sd_$i" } | Measure-Object -Average).Average
  $sd["w$i"] = if ($vW) { [math]::Round($vW,2) } else { 0 }
  $sd["h$i"] = if ($vH) { [math]::Round($vH,2) } else { 0 }
}
new Chart(document.getElementById('chartSocialDesirability'), {
  type: 'bar',
  data: {
    labels: ['sd_1\nCourteous', 'sd_2\nTook Advantage', 'sd_3\nGet Even', 'sd_4\nFeel Resentful', 'sd_5\nGood Listener'],
    datasets: [
      { label: 'Wife', data: [$($sd.w1), $($sd.w2), $($sd.w3), $($sd.w4), $($sd.w5)], backgroundColor: RED, borderRadius: 6 },
      { label: 'Husband', data: [$($sd.h1), $($sd.h2), $($sd.h3), $($sd.h4), $($sd.h5)], backgroundColor: NAVY, borderRadius: 6 }
    ]
  },
  options: {
    ...defaults,
    scales: { ...defaults.scales, y: { ...defaults.scales.y, min: 0, max: 2.5, ticks:{font:{family:'Inter',size:11},color:'#475569'}, title:{display:true,text:'Mean (1=True, 2=False)',font:{family:'Inter',size:11},color:'#475569'} } }
  }
});

// ── WELLBEING: Harassment Compare
new Chart(document.getElementById('chartHarassCompare'), {
  type: 'bar',
  data: {
    labels: ['Never', 'Rare', 'Somewhat Common'],
    datasets: [
      { label: 'Husbands (n=$nH)', data: [$($harH.never), $($harH.rare), $($harH.some)], backgroundColor: NAVY, borderRadius: 6 },
      { label: 'Wives (n=14)', data: [$($harW.never), $($harW.rare), $($harW.some)], backgroundColor: RED, borderRadius: 6 }
    ]
  },
  options: {
    ...defaults,
    scales: { ...defaults.scales, y: { ...defaults.scales.y, max: $([math]::Max($nH,$nW)+2), ticks:{stepSize:2,font:{family:'Inter',size:11},color:'#475569'} } }
  }
});
"@

# Find and replace the chart JS block in index.html
$startMarker = "// ── OVERVIEW: Composition Doughnut"
$endMarker   = "});"  # last chart ends with });

$startIdx = $html.IndexOf($startMarker)
# Find the end of the last chart block
$lastChartEnd = $html.LastIndexOf("`n});`n`n</script>")
if ($lastChartEnd -lt 0) { $lastChartEnd = $html.LastIndexOf("`n});`n</script>") }

if ($startIdx -ge 0 -and $lastChartEnd -ge 0) {
    $before = $html.Substring(0, $startIdx)
    $after  = $html.Substring($lastChartEnd + 5) # 5 = length of "});\n\n"
    $html = $before + $jsBlock + "`n`n" + $after
    Write-Host "Chart data updated successfully" -ForegroundColor Green
} else {
    Write-Host "WARNING: Could not find chart block markers — skipping JS update" -ForegroundColor Yellow
}

# Write updated HTML
$html | Set-Content "$DashboardDir\index.html" -Encoding UTF8
Write-Host "index.html written." -ForegroundColor Green

# ── Git commit and push
git -C $DashboardDir add index.html
$commitMsg = "Auto-update: $today (wives=$nW, husbands=$nH, wife_earn=PKR$wAvgEarn)"
git -C $DashboardDir commit -m $commitMsg
git -C $DashboardDir push origin main

Write-Host "`nDone! Dashboard updated and pushed to GitHub." -ForegroundColor Cyan
Write-Host "Live at: https://homebased.rs.org.pk" -ForegroundColor Green
