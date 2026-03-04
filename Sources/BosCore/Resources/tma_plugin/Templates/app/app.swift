import ProjectDescription

private let appNameAttribute: Template.Attribute = .required("name")
private let appOrganizationAttribute: Template.Attribute = .optional("organizationName", default: "axient")
private let appBundleIdAttribute: Template.Attribute = .optional("bundleIdPrefix", default: "com.example")
private let appTeamAttribute: Template.Attribute = .optional("teamId", default: "")
private let appDeploymentTargetAttribute: Template.Attribute = .optional("deploymentTarget", default: "17.0")
private let appRootFeatureAttribute: Template.Attribute = .optional("rootFeatureName", default: "Root")

let templateApp = Template(
    description: "App module scaffold (@Shared app-storage state + explicit lifecycle)",
    attributes: [
        appNameAttribute,
        appOrganizationAttribute,
        appBundleIdAttribute,
        appTeamAttribute,
        appDeploymentTargetAttribute,
        appRootFeatureAttribute
    ],
    items: [
        .file(path: "Projects/App/Project.swift", templatePath: "Project.stencil"),
        .file(path: "Projects/App/Sources/App.swift", templatePath: "App.stencil"),
        .file(path: "Projects/App/Sources/AppConstants.swift", templatePath: "AppConstants.stencil"),
        .file(path: "Projects/App/Sources/AppDelegate.swift", templatePath: "AppDelegate.stencil"),
        .file(path: "Projects/App/Sources/AppReducer.swift", templatePath: "AppReducer.stencil"),
        .file(path: "Projects/App/Sources/MainScreenView.swift", templatePath: "MainScreenView.stencil"),
        .file(path: "Projects/App/Sources/SplashView.swift", templatePath: "SplashView.stencil"),
        .file(path: "Projects/App/Sources/MaintenanceView.swift", templatePath: "MaintenanceView.stencil"),
        .file(path: "Projects/App/Sources/ForceUpdateView.swift", templatePath: "ForceUpdateView.stencil"),
        .file(path: "Projects/App/Sources/Core/AppBootstrapper.swift", templatePath: "CoreAppBootstrapper.stencil"),
        .file(path: "Projects/App/Sources/Core/ApplicationLifecycle.swift", templatePath: "CoreApplicationLifecycle.stencil"),
        .file(path: "Projects/App/Sources/Core/DeepLink.swift", templatePath: "CoreDeepLink.stencil"),
        .file(path: "Projects/App/Sources/Core/LocalizedRemoteConfig.swift", templatePath: "CoreLocalizedRemoteConfig.stencil"),
        .file(path: "Projects/App/Sources/Core/RouteRegistry.swift", templatePath: "CoreRouteRegistry.stencil"),
        .file(path: "Projects/App/Sources/Core/UpdateChecker.swift", templatePath: "CoreUpdateChecker.stencil"),
        .file(path: "Projects/App/Sources/Dependencies/AppComposition.swift", templatePath: "DependenciesAppComposition.stencil"),
        .file(path: "Projects/App/Sources/Dependencies/AnalyticsServices.swift", templatePath: "DependenciesAnalyticsServices.stencil"),
        .file(path: "Projects/App/Sources/Dependencies/DeepLinkServices.swift", templatePath: "DependenciesDeepLinkServices.stencil"),
        .file(path: "Projects/App/Sources/Dependencies/LifecycleServices.swift", templatePath: "DependenciesLifecycleServices.stencil"),
        .file(path: "Projects/App/Sources/Dependencies/RemoteConfigServices.swift", templatePath: "DependenciesRemoteConfigServices.stencil"),
        .file(path: "Projects/App/Tests/AppReducerTests.swift", templatePath: "AppReducerTests.stencil")
    ]
)
