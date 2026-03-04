import ProjectDescription

private let featureNameAttribute: Template.Attribute = .required("name")
private let featureOrganizationAttribute: Template.Attribute = .optional("organizationName", default: "axient")
private let featureBundleIdAttribute: Template.Attribute = .optional("bundleIdPrefix", default: "com.axiomorient")
private let featureTeamAttribute: Template.Attribute = .optional("teamId", default: "")
private let featureDeploymentTargetAttribute: Template.Attribute = .optional("deploymentTarget", default: "17.0")

let templateFeature = Template(
    description: "Feature module scaffold (single target + tests, no InterfaceKeys)",
    attributes: [
        featureNameAttribute,
        featureOrganizationAttribute,
        featureBundleIdAttribute,
        featureTeamAttribute,
        featureDeploymentTargetAttribute
    ],
    items: [
        .file(path: "Projects/Features/{{ name }}/Project.swift", templatePath: "Project.stencil"),
        .file(path: "Projects/Features/{{ name }}/Sources/Interface/{{ name }}FeatureInterface.swift", templatePath: "FeatureInterface.stencil"),
        .file(path: "Projects/Features/{{ name }}/Sources/{{ name }}Feature.swift", templatePath: "FeatureImplementation.stencil"),
        .file(path: "Projects/Features/{{ name }}/Sources/{{ name }}FeatureView.swift", templatePath: "FeatureView.stencil"),
        .file(path: "Projects/Features/{{ name }}/Sources/{{ name }}FeatureComposition.swift", templatePath: "FeatureComposition.stencil"),
        .file(path: "Projects/Features/{{ name }}/Tests/{{ name }}FeatureTests.swift", templatePath: "FeatureTests.stencil")
    ]
)
