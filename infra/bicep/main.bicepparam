using './main.bicep'

param prefix = 'ttmh'
param location = 'swedencentral'
param suffix = toLower(readEnvironmentVariable('TTMH_SUFFIX', 'dev001'))
param adminObjectId = readEnvironmentVariable('TTMH_ADMIN_OBJECT_ID', '')
param enableDefender = true
