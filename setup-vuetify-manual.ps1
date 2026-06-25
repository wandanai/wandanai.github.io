param(
    [string]$ProjDir
)

Write-Host "============================================"
Write-Host "  Auto Setup Vuetify (Manual Method) on Nuxt"
Write-Host "============================================"
Write-Host ""

if (-not $ProjDir) {
    $ProjDir = Read-Host "วางพาทโฟลเดอร์โปรเจกต์ Nuxt (เช่น D:\my-app)"
}

$ProjDir = $ProjDir.Trim('"').Trim()

if (-not (Test-Path $ProjDir)) {
    Write-Host "[ERROR] ไม่พบโฟลเดอร์: $ProjDir" -ForegroundColor Red
    Read-Host "กด Enter เพื่อปิด"
    exit 1
}

Set-Location $ProjDir

$configTs = Join-Path $ProjDir "nuxt.config.ts"
$configJs = Join-Path $ProjDir "nuxt.config.js"

if (-not (Test-Path $configTs) -and -not (Test-Path $configJs)) {
    Write-Host "[ERROR] ไม่พบ nuxt.config.ts/js - โฟลเดอร์นี้ไม่ใช่โปรเจกต์ Nuxt" -ForegroundColor Red
    Read-Host "กด Enter เพื่อปิด"
    exit 1
}

$configFile = if (Test-Path $configTs) { $configTs } else { $configJs }

Write-Host "[OK] พบโปรเจกต์ Nuxt ที่ $ProjDir"
Write-Host ""

# เช็คว่ามี vuetify-nuxt-module ติดตั้งจากรอบก่อนไหม -> ถอนออกก่อน เพราะชนกับวิธี manual
$pkgPath = Join-Path $ProjDir "package.json"
if (Test-Path $pkgPath) {
    $pkgContent = Get-Content $pkgPath -Raw
    if ($pkgContent -match "vuetify-nuxt-module") {
        Write-Host "[WARNING] พบ vuetify-nuxt-module ติดตั้งอยู่ - กำลังถอนออกก่อน (ชนกับวิธี manual)" -ForegroundColor Yellow
        npm uninstall vuetify-nuxt-module
        Write-Host ""
    }
}

# ติดตั้ง package ที่จำเป็น
Write-Host "กำลังติดตั้ง vuetify, vite-plugin-vuetify, @mdi/font ..."
npm i -D vuetify vite-plugin-vuetify "@mdi/font"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] npm install ล้มเหลว ตรวจสอบ error ข้างบน" -ForegroundColor Red
    Read-Host "กด Enter เพื่อปิด"
    exit 1
}
Write-Host ""

# 1) เขียน nuxt.config.ts (backup ตัวเก่าก่อนเสมอ)
$backupConfig = "$configFile.bak"
Copy-Item $configFile $backupConfig -Force
Write-Host "[OK] สำรอง $([System.IO.Path]::GetFileName($configFile)) ไว้ที่ $([System.IO.Path]::GetFileName($backupConfig))"

$nuxtConfigContent = @'
import vuetify, { transformAssetUrls } from 'vite-plugin-vuetify'

export default defineNuxtConfig({
  build: {
    transpile: ['vuetify'],
  },
  vite: {
    plugins: [
      // @ts-expect-error
      vuetify({ autoImport: true }),
    ],
    vue: {
      template: {
        transformAssetUrls,
      },
    },
  },
})
'@

Set-Content -Path $configFile -Value $nuxtConfigContent -Encoding utf8
Write-Host "[OK] เขียน $([System.IO.Path]::GetFileName($configFile)) ใหม่แล้ว"
Write-Host "     ถ้าของเดิมมี config อื่นอยู่ด้วย (modules อื่น/css อื่น) ให้เปิดไฟล์ .bak แล้ว merge กลับเข้าไปเอง"
Write-Host ""

# 2) plugins/vuetify.ts
$pluginsDir = Join-Path $ProjDir "plugins"
if (-not (Test-Path $pluginsDir)) {
    New-Item -ItemType Directory -Path $pluginsDir | Out-Null
}

$pluginContent = @'
// import this after install `@mdi/font` package
import '@mdi/font/css/materialdesignicons.css'
import 'vuetify/styles'
import { createVuetify } from 'vuetify'

export default defineNuxtPlugin((app) => {
  const vuetify = createVuetify({
    // ... your configuration
  })
  app.vueApp.use(vuetify)
})
'@

$pluginPath = Join-Path $pluginsDir "vuetify.ts"
if (Test-Path $pluginPath) {
    Copy-Item $pluginPath "$pluginPath.bak" -Force
    Write-Host "[INFO] พบ plugins/vuetify.ts เดิม - สำรองเป็น vuetify.ts.bak แล้วเขียนใหม่"
}
Set-Content -Path $pluginPath -Value $pluginContent -Encoding utf8
Write-Host "[OK] สร้าง plugins/vuetify.ts แล้ว"
Write-Host ""

# 3) app.vue - ห่อ <NuxtPage /> ด้วย <v-app> โดยไม่ทับเนื้อหาอื่นถ้าทำได้
$appVuePath = Join-Path $ProjDir "app.vue"
if (Test-Path $appVuePath) {
    $appContent = Get-Content $appVuePath -Raw
    if ($appContent -match "<v-app") {
        Write-Host "[INFO] app.vue มี <v-app> อยู่แล้ว ไม่แก้ไข"
    } elseif ($appContent -match "<NuxtPage\s*/>") {
        Copy-Item $appVuePath "$appVuePath.bak" -Force
        $newAppContent = $appContent -replace "<NuxtPage\s*/>", "<v-app>`n      <NuxtPage />`n    </v-app>"
        Set-Content -Path $appVuePath -Value $newAppContent -Encoding utf8
        Write-Host "[OK] เพิ่ม <v-app> ครอบ <NuxtPage /> ใน app.vue แล้ว (ของเดิม backup เป็น app.vue.bak)"
    } else {
        Write-Host "[WARNING] app.vue มีโครงสร้างไม่ตรงกับที่คาดไว้ - ไม่แก้ไขให้อัตโนมัติ" -ForegroundColor Yellow
        Write-Host "          กรุณาเปิด app.vue แล้วเพิ่ม <v-app> ครอบเนื้อหาภายในเอง"
    }
} else {
    $defaultApp = @'
<template>
  <NuxtLayout>
    <v-app>
      <NuxtPage />
    </v-app>
  </NuxtLayout>
</template>
'@
    Set-Content -Path $appVuePath -Value $defaultApp -Encoding utf8
    Write-Host "[OK] ไม่พบ app.vue เดิม - สร้างใหม่ให้แล้ว"
}
Write-Host ""

# 4) pages/index.vue (ไฟล์เปล่า ถ้ายังไม่มี - ไม่ทับของเดิม)
$pagesDir = Join-Path $ProjDir "pages"
if (-not (Test-Path $pagesDir)) {
    New-Item -ItemType Directory -Path $pagesDir | Out-Null
}
$indexPath = Join-Path $pagesDir "index.vue"
if (-not (Test-Path $indexPath)) {
    New-Item -ItemType File -Path $indexPath | Out-Null
    Write-Host "[OK] สร้าง pages/index.vue เปล่าให้แล้ว - ไปเขียนเนื้อหาเองได้เลย"
} else {
    Write-Host "[INFO] พบ pages/index.vue อยู่แล้ว ไม่แตะ"
}
Write-Host ""

# 5) public/img
$imgDir = Join-Path $ProjDir "public\img"
if (-not (Test-Path $imgDir)) {
    New-Item -ItemType Directory -Path $imgDir -Force | Out-Null
    Write-Host "[OK] สร้าง public/img ให้แล้ว"
} else {
    Write-Host "[INFO] พบ public/img อยู่แล้ว"
}

Write-Host ""
Write-Host "============================================"
Write-Host "  เสร็จแล้ว! รัน: npm run dev"
Write-Host "  ถ้าของเดิม config/app.vue มีเนื้อหาอื่น"
Write-Host "  เช็คไฟล์ .bak ที่สำรองไว้แล้ว merge กลับเอง"
Write-Host "============================================"
Read-Host "กด Enter เพื่อปิด"
