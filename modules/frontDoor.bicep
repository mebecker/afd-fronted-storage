param frontDoorName string
param storageAccountId string
param storageAccountBlobEndpoint string
param allowedIpAddresses array = []

resource frontDoor 'Microsoft.Cdn/profiles@2023-07-01-preview' = {
  name: frontDoorName
  location: 'Global'
  tags: {
  }
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-07-01-preview' = {
  name: frontDoorName
  location: 'Global'
  tags: {
  }
  parent: frontDoor
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-07-01-preview' = {
  name: 'default-origin-group-${uniqueString(frontDoorName)}'
  parent: frontDoor
  properties: {
    healthProbeSettings: {
      probeIntervalInSeconds: 100
      probePath: '/'
      probeProtocol: 'Https'
      probeRequestType: 'HEAD'
    }
    loadBalancingSettings: {
      additionalLatencyInMilliseconds: 50
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    sessionAffinityState: 'Disabled'
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-07-01-preview' = {
  name: 'default-origin'
  parent: frontDoorOriginGroup
  properties: {
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
    hostName: storageAccountBlobEndpoint
    httpPort: 80
    httpsPort: 443
    originHostHeader: storageAccountBlobEndpoint
    priority: 1
    sharedPrivateLinkResource: {
      groupId: 'blob'
      privateLink: {
        id: storageAccountId
      }
      privateLinkLocation: resourceGroup().location
      requestMessage: 'auto-generated via bicep'
    }
    weight: 1000
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-07-01-preview' = {
  name: 'default-route'
  dependsOn: [
    frontDoorOrigin
  ]
  parent: frontDoorEndpoint
  properties: {
    customDomains: []
    enabledState: 'Enabled'
    forwardingProtocol: 'MatchRequest'
    httpsRedirect: 'Enabled'
    linkToDefaultDomain: 'Enabled'
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    patternsToMatch: [
      '/*'
    ]
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
  }
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: frontDoorName
  location: resourceGroup().location
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    customRules: {
      rules: [
        {
          action: 'Block'
          enabledState: 'Enabled'
          matchConditions: [
            {
              matchValue: allowedIpAddresses
              matchVariable: 'RemoteAddr'
              negateCondition: true
              operator: 'IPMatch'
              transforms: []
            }
          ]
          name: 'denyAllIPsExceptAllowed'
          priority: 1
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          ruleType: 'MatchRule'
        }
      ]
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetAction: 'Block'
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleGroupOverrides: []
          exclusions: []
        }
      ]
    }
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
    }
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-07-01-preview' = {
  name: 'string'
  parent: frontDoor
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
      wafPolicy: {
        id: wafPolicy.id
      }
    }
  }
}

output frontDoorUrl string = frontDoorEndpoint.properties.hostName
