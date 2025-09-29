{{/*
Expand the name of the chart.
*/}}
{{- define "cnpg-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cnpg-cluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" $name .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cnpg-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cnpg-cluster.labels" -}}
helm.sh/chart: {{ include "cnpg-cluster.chart" . }}
{{ include "cnpg-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cnpg-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cnpg-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cnpg-cluster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cnpg-cluster.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Sanitized compute size factor (minimum 1)
*/}}
{{- define "cnpg-cluster.computeFactor" -}}
{{- $raw := .Values.computeSizeFactor | default 1 -}}
{{- $f := (printf "%v" $raw | atoi) -}}
{{- if lt $f 1 }}{{- $f = 1 }}{{- end -}}
{{- $f -}}
{{- end }}

{{/*
Memory per factor in MB (override with .Values.memoryPerFactorMB, default 512MB)
*/}}
{{- define "cnpg-cluster.memoryPerFactorMB" -}}
{{- (.Values.memoryPerFactorMB | default 128) | int -}}
{{- end }}

{{/*
Total memory (MB) allocated to a PostgreSQL pod
*/}}
{{- define "cnpg-cluster.totalMemoryMB" -}}
{{- $f := include "cnpg-cluster.computeFactor" . | int -}}
{{- $unit := include "cnpg-cluster.memoryPerFactorMB" . | int -}}
{{- mul $f $unit -}}
{{- end }}

{{/*
CPU per factor in millicores (override with .Values.cpuPerFactorMillicores, default 75m)
*/}}
{{- define "cnpg-cluster.cpuPerFactorMillicores" -}}
{{- (.Values.cpuPerFactorMillicores | default 75) | int -}}
{{- end }}

{{/*
Total CPU (millicores) allocated to a PostgreSQL pod
*/}}
{{- define "cnpg-cluster.totalCPUMillicores" -}}
{{- $f := include "cnpg-cluster.computeFactor" . | int -}}
{{- $unit := include "cnpg-cluster.cpuPerFactorMillicores" . | int -}}
{{- mul $f $unit -}}
{{- end }}

{{/*
shared_buffers = 25% total memory
*/}}
{{- define "cnpg-cluster.sharedBuffersMB" -}}
{{- $total := include "cnpg-cluster.totalMemoryMB" . | int -}}
{{- div (mul $total 25) 100 -}}
{{- end }}

{{/*
max_connections = (compute size factor * 5) + 5
*/}}
{{- define "cnpg-cluster.maxConnections" -}}
{{- .Values.computeSizeFactor | mul 5 | add 5 }}
{{- end }}

{{/*
work_mem = (25% total) / max_connections
*/}}
{{- define "cnpg-cluster.workMemMB" -}}
{{- $total := include "cnpg-cluster.totalMemoryMB" . | int -}}
{{- $maxConn := include "cnpg-cluster.maxConnections" . | int -}}
{{- if lt $maxConn 1 }}{{- $maxConn = 1 }}{{- end -}}
{{- $quarter := div (mul $total 25) 100 -}}
{{- $per := div (max 1 $quarter) $maxConn -}}
{{- if lt $per 1 }}1{{ else }}{{ $per }}{{ end }}
{{- end }}

{{/*
maintenance_work_mem = 5% total
*/}}
{{- define "cnpg-cluster.maintenanceWorkMemMB" -}}
{{- $total := include "cnpg-cluster.totalMemoryMB" . | int -}}
{{ div (mul $total 5) 100 }}
{{- end }}

{{/*
effective_cache_size = 50% total memory
*/}}
{{- define "cnpg-cluster.effectiveCacheSizeMB" -}}
{{- $total := include "cnpg-cluster.totalMemoryMB" . | int -}}
{{- div (mul $total 50) 100 -}}
{{- end }}

{{/*
Pooler sizing helpers
*/}}
{{- define "cnpg-cluster.pooler.maxDbConnections" -}}
{{- $clusterMax := include "cnpg-cluster.maxConnections" . | int -}}
{{- $reserve := 5 -}}
{{- $v := sub $clusterMax $reserve -}}
{{- if lt $v 5 }}5{{ else }}{{ $v }}{{ end }}
{{- end }}

{{- define "cnpg-cluster.pooler.maxClientConn" -}}
{{- /* Allow more frontend connections: 10x db connections */ -}}
{{- $db := include "cnpg-cluster.pooler.maxDbConnections" . | int -}}
{{ mul $db 10 }}
{{- end }}

{{- define "cnpg-cluster.pooler.defaultPoolSize" -}}
{{- /* 50% of max_db_connections, min 5 */ -}}
{{- $db := include "cnpg-cluster.pooler.maxDbConnections" . | int -}}
{{- $v := div (mul $db 50) 100 -}}
{{- if lt $v 5 }}5{{ else }}{{ $v }}{{ end }}
{{- end }}

{{- define "cnpg-cluster.now" -}}
{{- /* Renders current time in configured timezone (Values.timezone), falls back to local system tz */ -}}
{{- $tz := .Values.timezone | default "Local" -}}
{{- dateInZone "2006-01-02T15:04:05-07:00" (now) $tz -}}
{{- end }}

{{/*
Schedule for automatic backups
*/}}
{{- define "cnpg-cluster.randomBackupSchedule" -}}
{{- /* Deterministic pseudo-random schedule between 03:00–04:59 (UTC+8) */ -}}
{{- /* Uses adler32 hash so it is stable across renders (good for GitOps) */ -}}
{{- $seed := adler32sum (printf "%s-%s" .Release.Name .Release.Namespace) -}}
{{- $offset := mod $seed 120 -}}          {{/* 0..119 minutes in 2h window */}}
{{- $hour := add 19 (div $offset 60) -}}    {{/* 3 or 4 */}}
{{- $minute := mod $offset 60 -}}
{{- printf "0 %02d %d * * *" $minute $hour -}}
{{- end }}
