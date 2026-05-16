apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
  annotations:
    policies.kyverno.io/title: Disallow Latest Tag
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/description: >-
      The ':latest' tag is mutable and can lead to unexpected behavior.
      This policy ensures pods use immutable image tags for traceability.
spec:
  validationFailureAction: ${action}
  background: true
  rules:
  - name: require-image-tag
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "An image tag ':latest' is required. Use a specific immutable tag."
      pattern:
        spec:
          containers:
          - image: "!*:latest"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  annotations:
    policies.kyverno.io/title: Require Resource Limits
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/description: >-
      Ensures all containers have resource limits and requests defined.
spec:
  validationFailureAction: ${action}
  background: true
  rules:
  - name: check-resources
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Resource limits and requests are required."
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
              requests:
                memory: "?*"
                cpu: "?*"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-readiness-probe
  annotations:
    policies.kyverno.io/title: Require Readiness Probe
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: low
    policies.kyverno.io/description: >-
      Ensures all pods have a readiness probe configured.
spec:
  validationFailureAction: ${action}
  background: true
  rules:
  - name: check-readiness-probe
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "A readiness probe is required."
      pattern:
        spec:
          containers:
          - readinessProbe:
              ">": ""
