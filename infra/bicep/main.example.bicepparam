using './main.bicep'

param prefix = 'ttmh'
param location = 'swedencentral'
param suffix = '<unique-six-character-suffix>'
param adminObjectId = '<entra-object-id-for-key-vault-rbac-or-empty>'
param enableDefender = true
