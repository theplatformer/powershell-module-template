. $PSScriptRoot\..\_InitializeTests.ps1

Describe 'Add-YourFirstFunction' {

  Context "When not passed any parameters." {

    It 'Should write correct output.' {
      Add-YourFirstFunction | Should -Be "Your first function ran!"
    }

  }
  
}