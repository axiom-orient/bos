import ProjectDescription

private let serviceNameAttribute: Template.Attribute = .required("name")
private let serviceOrganizationAttribute: Template.Attribute = .optional("organizationName", default: "axient")
private let serviceBundleIdAttribute: Template.Attribute = .optional("bundleIdPrefix", default: "com.axiomorient")
private let serviceTeamAttribute: Template.Attribute = .optional("teamId", default: "")
private let serviceDeploymentTargetAttribute: Template.Attribute = .optional("deploymentTarget", default: "17.0")

let templateService = Template(
    description: "Service module scaffold (Interface + Sources + Tests, no InterfaceKeys)",
    attributes: [
        serviceNameAttribute,
        serviceOrganizationAttribute,
        serviceBundleIdAttribute,
        serviceTeamAttribute,
        serviceDeploymentTargetAttribute
    ],
    items: [
        .file(path: "Projects/Services/{{ name }}/Project.swift", templatePath: "Project.stencil"),
        .file(path: "Projects/Services/{{ name }}/Interface/{{ name }}Service.swift", templatePath: "ServiceInterface.stencil"),
        .file(path: "Projects/Services/{{ name }}/Sources/Live{{ name }}Service.swift", templatePath: "ServiceImplementation.stencil"),
        .file(path: "Projects/Services/{{ name }}/Tests/{{ name }}ServiceTests.swift", templatePath: "ServiceTests.stencil")
    ]
)
