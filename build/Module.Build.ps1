# Task for installing Pester if not present.
Add-BuildTask EnsurePester {
  if (!(Get-InstalledModule -Name Pester -MinimumVersion '4.7.3')) {
    Install-Module -Name Pester -MinimumVersion '4.7.3' -Scope CurrentUser -Repository PSGallery
  }
}

# Task for installing platyPS if not present.
Add-BuildTask EnsurePlatyPS {
  if (!(Get-InstalledModule -Name platyPS -MinimumVersion '0.13.0')) {
    Install-Module -Name platyPS -MinimumVersion '0.13.0' -Scope CurrentUser -Repository PSGallery
  }
}

# Task for installing PSScriptAnalyzer if not present.
Add-BuildTask EnsurePSScriptAnalyzer {
  if (!(Get-InstalledModule -Name PSScriptAnalyzer -MinimumVersion '1.18.0')) {
    Install-Module -Name PSScriptAnalyzer -MinimumVersion '1.18.0' -Scope CurrentUser -Repository PSGallery
  }
}

# Task for installing New-VSCodeTask if not present.
Add-BuildTask EnsureNewVSCodeTask {
  if (!(Get-InstalledScript -Name New-VSCodeTask -MinimumVersion '1.1.7')) {
    Install-Script -Name New-VSCodeTask -MinimumVersion '1.1.7' -Scope CurrentUser -Repository PSGallery
  }
}

# Task for generating a new/updated tasks.json for VS Code workspace.
Add-BuildTask GenerateVSCodeTasks EnsureNewVSCodeTask, {
  New-VSCodeTask.ps1
}

# Task for invoking PSScriptAnalyzer at the project root.
Add-BuildTask Analyze EnsurePSScriptAnalyzer, {
  $Results = Invoke-ScriptAnalyzer -Path $BuildRoot -Recurse
  if ($Results) {
    $Results | Format-Table
    throw "One or more PSScriptAnalyzer errors/warnings where found."
  }
}

# Task for running all Pester tests within the project.
Add-BuildTask Test EnsurePester, {
  $Results = Invoke-Pester -Path $BuildRoot\tests -PassThru
  Assert-Build($Results.FailedCount -eq 0) ('Failed "{0}" Pester tests.' -f $Results.FailedCount)
}

# Task for creating/cleaning the \build output directory.
Add-BuildTask Clean {
  $SourceDirectory = "$BuildRoot\src"
  $Module = Get-ChildItem -Path $SourceDirectory -Filter *.psd1 -Recurse | Select-Object -First 1
  $BuildDirectory = "$BuildRoot\build\$($Module.BaseName)" 
  if (!(Test-Path -Path $BuildDirectory)) {
    New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
  }
  if (Test-Path -Path $BuildDirectory) {
    Remove-Item "$BuildDirectory\*" -Recurse -Force
  }
}

# Task for compiling all the individual function files into a single PSM1 module file.
Add-BuildTask Compile {
  $SourceDirectory = "$BuildRoot\src"
  $Module = Get-ChildItem -Path $SourceDirectory -Filter *.psd1 -Recurse | Select-Object -First 1
  $BuildDirectory = "$BuildRoot\build\$($Module.BaseName)" 
  $DestinationModule = "$BuildDirectory\$($Module.BaseName).psm1"
  $PublicFunctions = Get-ChildItem -Path $SourceDirectory -Include 'public' -Recurse -Directory | Get-ChildItem -Include *.ps1 -File
  $PrivateFunctions = Get-ChildItem -Path $SourceDirectory -Include 'private' -Recurse -Directory | Get-ChildItem -Include *.ps1 -File

  if ($PrivateFunctions) {
    Write-Output "Found $($PrivateFunctions.Count) Private functions, will compile these into the root module file."
    Foreach ($PrivateFunction in $PrivateFunctions) {
      Get-Content -Path $PrivateFunction.FullName | Add-Content -Path $DestinationModule
      Add-Content -Path $DestinationModule -Value ""
    }
  }

  if ($PublicFunctions) {
    Write-Output "Found $($PublicFunctions.Count) Public functions, will compile these into the root module file."
    Foreach ($PublicFunction in $PublicFunctions) {
      Get-Content -Path $PublicFunction.FullName | Add-Content -Path $DestinationModule
      Add-Content -Path $DestinationModule -Value ""
    }
  }
  
  $PublicFunctionNames = $PublicFunctions | Select-String -Pattern 'function (\w+-\w+) {' -AllMatches | ForEach-Object { $_.Matches.Groups[1].Value }
  Write-Output "Making $($PublicFunctionNames.Count) functions available via Export-ModuleMember"
  "Export-ModuleMember -Function {0}" -f ($PublicFunctionNames -join ', ') | Add-Content $DestinationModule

  Copy-Item -Path $Module.FullName -Destination $BuildDirectory

}

# Task for generating PowerShell external help files from source markdown files, using platyPS.
Add-BuildTask GenerateHelp EnsurePlatyPS, {
  $SourceDirectory = "$BuildRoot\src"
  $Module = Get-ChildItem -Path $SourceDirectory -Filter *.psd1 -Recurse | Select-Object -First 1
  $BuildDirectory = "$BuildRoot\build\$($Module.BaseName)" 
  $DocsSource = "$SourceDirectory\docs"
  $HelpLocales = (Get-ChildItem -Path $DocsSource -Directory).Name

  if ($HelpLocales) {
    foreach ($Locale in $HelpLocales) {
      if (Get-ChildItem -LiteralPath $DocsSource\$Locale -Filter *.md -Recurse -ErrorAction SilentlyContinue) {
        New-ExternalHelp -Path $DocsSource\$Locale -OutputPath $BuildDirectory\$Locale -Force -ErrorAction SilentlyContinue > $null
      }
      else {
        Write-Output "No markdown help files to process for $Locale locale."
      }
    }
  }
  else {
    Write-Output "No markdown help locales found. Skipping $($Task.Name) task."
    return
  }
}

# Main 'Build' task to run all preceeding tasks and package the module ready for production.
Add-BuildTask Build Analyze, Test, Clean, Compile, GenerateHelp

# Alias Invoke-Build's default task to the main 'Build' task.
Add-BuildTask . Build

# Task for publishing the built module to the PowerShell Gallery, which will also run a build.
Add-BuildTask Publish Build, {
  $SourceDirectory = "$BuildRoot\src"
  $Module = Get-ChildItem -Path $SourceDirectory -Filter *.psd1 -Recurse | Select-Object -First 1
  $BuildDirectory = "$BuildRoot\build\$($Module.BaseName)" 
  $Manifest = Import-PowerShellDataFile -Path $Module.FullName
  $ModuleVersion = $Manifest.ModuleVersion

  Assert-Build ($env:PSGalleryAPIKey) "PowerShell Gallery API Key environment variable not found!"
  Try {
    $Params = @{
      Path        = "$BuildDirectory"
      NuGetApiKey = $env:PSGalleryAPIKey
      ErrorAction = "Stop"
    }
    Publish-Module @Params
    Write-Output "$($Module.BaseName) $ModuleVersion published to the PowerShell Gallery!"
  }
  Catch {
    throw $_
  }

}