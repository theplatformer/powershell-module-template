# PSScriptAnalyzer Settings Object
# https://github.com/PowerShell/PSScriptAnalyzer#settings-support-in-scriptanalyzer

@{
  # Only report warnings and errors, skip information items.
  Severity     = @('Error', 'Warning')

  # Specify rules to explicitly include, when you want to run only a subset of the default rule set.
  IncludeRules = @()

  # Specify rules to exclude, when you want to run most of the default set of rules except for some specific ones.
  ExcludeRules = @('PSUseToExportFieldsInManifest')

  # Pass parameters to rules that take parameters.
  Rules        = @{
    # Check if cmdlets are compatible on PowerShell Core
    PSUseCompatibleCmdlets = @{
      Compatibility = @("core-6.1.0-windows", "core-6.1.0-linux", "core-6.1.0-macos") 
    }
  }
}