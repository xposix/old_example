{{/*
Expand the name of the chart.
*/}}
{{- define "client-app.name" -}}
{{- default .Chart.Name .Values.clientApp.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "client-app.fullname" -}}
{{- if .Values.clientApp.fullnameOverride }}
{{- .Values.clientApp.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.clientApp.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "client-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "client-app.labels" -}}
helm.sh/chart: {{ include "client-app.chart" . }}
{{ include "client-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "client-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "client-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "client-app.serviceAccountName" -}}
{{- if .Values.clientApp.serviceAccount.create }}
{{- default (include "client-app.fullname" .) .Values.clientApp.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.clientApp.serviceAccount.name }}
{{- end }}
{{- end }}

#################################################
{{/*
Expand the name of the chart.
*/}}
{{- define "celery.name" -}}
{{- default .Values.celery.nameOverride| trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "celery.fullname" -}}
{{- if .Values.celery.fullnameOverride }}
{{- .Values.celery.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Values.celery.nameOverride}}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "celery.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "celery.labels" -}}
helm.sh/chart: {{ include "celery.chart" . }}
{{ include "celery.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "celery.selectorLabels" -}}
app.kubernetes.io/name: {{ include "celery.name" . }}
app.kubernetes.io/instance: {{ include "celery.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "celery.serviceAccountName" -}}
{{- if .Values.celery.serviceAccount.create }}
{{- default (include "celery.fullname" .) .Values.celery.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.celery.serviceAccount.name }}
{{- end }}
{{- end }}
