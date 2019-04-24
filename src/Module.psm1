## Running A Build Will Compile This To A Single PSM1 File Containing All Module Code ##

## If Importing Module Source Directly, This Will Dynamically Build Root Module ##

# Get list of private functions and public functions to import, in order.
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private -Recurse -Filter "*.ps1") | Sort-Object Name
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public -Recurse -Filter "*.ps1") | Sort-Object Name

# Dot source the private function files.
foreach ($ImportItem in $Private) {
  try {
    . $ImportItem.FullName
    Write-Verbose -Message ("Imported private function {0}" -f $ImportItem.FullName)
  }
  catch {
    Write-Error -Message ("Failed to import private function {0}: {1}" -f $ImportItem.FullName, $_)
  }
}

# Dot source the public function files.
foreach ($ImportItem in $Public) {
  try {
    . $ImportItem.FullName
    Write-Verbose -Message ("Imported public function {0}" -f $ImportItem.FullName)
  }
  catch {
    Write-Error -Message ("Failed to import public function {0}: {1}" -f $ImportItem.FullName, $_)
  }
}

# Export the public functions.
Export-ModuleMember -Function $Public.BaseName