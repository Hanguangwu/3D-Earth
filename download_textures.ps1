# PowerShell script to download Earth textures

$texturePath = "$PSScriptRoot\public\textures"

# Create directory if it doesn't exist
if (!(Test-Path $texturePath)) {
    New-Item -ItemType Directory -Path $texturePath -Force
}

# Define texture URLs from Solar System Scope
$textureUrls = @{
    "earth_daymap.jpg" = "https://www.solarsystemscope.com/textures/download/2k_earth_daymap.jpg"
    "earth_bumpmap.jpg" = "https://www.solarsystemscope.com/textures/download/2k_earth_normal_map.tif"
    "earth_specular.jpg" = "https://www.solarsystemscope.com/textures/download/2k_earth_specular_map.tif"
    "earth_clouds.png" = "https://www.solarsystemscope.com/textures/download/2k_earth_clouds.jpg"
}

# Download each texture
foreach ($texture in $textureUrls.GetEnumerator()) {
    $outputFile = Join-Path $texturePath $texture.Key
    Write-Host "Downloading $($texture.Key) from $($texture.Value)..."
    
    try {
        Invoke-WebRequest -Uri $texture.Value -OutFile $outputFile
        Write-Host "Downloaded $($texture.Key) successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to download $($texture.Key): $_" -ForegroundColor Red
    }
}

Write-Host "All textures downloaded to $texturePath" -ForegroundColor Cyan