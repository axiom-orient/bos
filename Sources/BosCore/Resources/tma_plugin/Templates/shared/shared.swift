import ProjectDescription

private let sharedNameAttribute: Template.Attribute = .required("name")
private let sharedOrganizationAttribute: Template.Attribute = .optional("organizationName", default: "axient")
private let sharedBundleIdAttribute: Template.Attribute = .optional("bundleIdPrefix", default: "com.axiomorient")
private let sharedTeamAttribute: Template.Attribute = .optional("teamId", default: "")
private let sharedDeploymentTargetAttribute: Template.Attribute = .optional("deploymentTarget", default: "17.0")

let templateShared = Template(
    description: "Shared module scaffold (single target, no tests)",
    attributes: [
        sharedNameAttribute,
        sharedOrganizationAttribute,
        sharedBundleIdAttribute,
        sharedTeamAttribute,
        sharedDeploymentTargetAttribute
    ],
    items: [
        .file(path: "Projects/Shared/{{ name }}/Project.swift", templatePath: "Project.stencil"),
        .file(path: "Projects/Shared/{{ name }}/Sources/{{ name }}Style.swift", templatePath: "SharedModule.stencil")
    ]
)
