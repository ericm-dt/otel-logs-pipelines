{{/*
------------------------------------------------------------------------------
boa.image
Resolves the full image reference for a service.

Call: {{ include "boa.image" (list . .Values.userservice "userservice") }}
  args[0] = root context ($)
  args[1] = service values dict (e.g. .Values.userservice)
  args[2] = image name as it appears in the registry (may differ from values key)

Resolution order:
  1. svc.image.repository (full repo override) + svc.image.tag or global.imageTag
  2. global.imageRegistry/imageName + svc.image.tag or global.imageTag
------------------------------------------------------------------------------
*/}}
{{- define "boa.image" -}}
{{- $root     := index . 0 -}}
{{- $svc      := index . 1 -}}
{{- $imgName  := index . 2 -}}
{{- $globalReg := $root.Values.global.imageRegistry -}}
{{- $globalTag := $root.Values.global.imageTag -}}
{{- $repo := dig "image" "repository" "" $svc | default (printf "%s/%s" $globalReg $imgName) -}}
{{- $tag  := dig "image" "tag"        "" $svc | default $globalTag -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}

{{/*
------------------------------------------------------------------------------
boa.imagePullPolicy
Returns the global imagePullPolicy.
------------------------------------------------------------------------------
*/}}
{{- define "boa.imagePullPolicy" -}}
{{- .Values.global.imagePullPolicy -}}
{{- end -}}

{{/*
------------------------------------------------------------------------------
boa.podAnnotations
Merges global.podAnnotations with service-level podAnnotations.
Service-level annotations take precedence over global annotations.

Call: {{ include "boa.podAnnotations" (list .Values.global.podAnnotations .Values.userservice.podAnnotations) }}
------------------------------------------------------------------------------
*/}}
{{- define "boa.podAnnotations" -}}
{{- $global := index . 0 | default dict -}}
{{- $svc    := index . 1 | default dict -}}
{{- $merged := merge (deepCopy $svc) $global -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end -}}

{{/*
------------------------------------------------------------------------------
boa.selectorLabels
Standard selector labels for a service.
------------------------------------------------------------------------------
*/}}
{{- define "boa.selectorLabels" -}}
app: {{ . }}
app.kubernetes.io/part-of: bank-of-anthos
{{- end -}}

{{/*
------------------------------------------------------------------------------
boa.jwtPublicKeyVolume
Declares the jwt-key volume (referenced in pod specs that need the public key).
------------------------------------------------------------------------------
*/}}
{{- define "boa.jwtPublicKeyVolume" -}}
- name: jwt-key
  secret:
    secretName: {{ .Values.jwtKey.secretName }}
    items:
      - key: jwtRS256.key.pub
        path: publickey
{{- end -}}

{{/*
------------------------------------------------------------------------------
boa.jwtPrivateKeyVolume
Declares the jwt-key volume including the private key (userservice only).
------------------------------------------------------------------------------
*/}}
{{- define "boa.jwtPrivateKeyVolume" -}}
- name: jwt-key
  secret:
    secretName: {{ .Values.jwtKey.secretName }}
    items:
      - key: jwtRS256.key
        path: privatekey
      - key: jwtRS256.key.pub
        path: publickey
{{- end -}}
