#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(readlink -e $(dirname "$BASH_SOURCE[0]")/../)"

CONVERGED="${CONVERGED:-true}"
DEPLOY_DIR="${PROJECT_ROOT}/deploy"

NAMESPACE="${NAMESPACE:-kubevirt-hyperconverged}"
CSV_VERSION="${CSV_VERSION:-0.0.1}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-kubevirt}"
CNA_CONTAINER_PREFIX="${CNA_CONTAINER_PREFIX:-quay.io/kubevirt}"
WEBUI_CONTAINER_PREFIX="${WEBUI_CONTAINER_PREFIX:-quay.io/kubevirt}"
CONTAINER_TAG="${CONTAINER_TAG:-latest}"
IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-IfNotPresent}"
CSV_DIR="olm-catalog/kubevirt-hyperconverged/${CSV_VERSION}"

(cd ${PROJECT_ROOT}/tools/manifest-templator/ && go build)

templates=$(cd ${PROJECT_ROOT}/templates && find . -type f -name "*.yaml.in")
for template in $templates; do
	infile="${PROJECT_ROOT}/templates/${template}"

	if [ "$CONVERGED" = true ]; then
		rendered=$( \
			${PROJECT_ROOT}/tools/manifest-templator/manifest-templator \
			--converged \
			--namespace=${NAMESPACE} \
			--csv-version=${CSV_VERSION} \
			--container-prefix=${CONTAINER_PREFIX} \
			--container-tag=${CONTAINER_TAG} \
			--image-pull-policy=${IMAGE_PULL_POLICY} \
			--input-file=${infile} \
		)
	else
		# Leaving this around so it's possible to build HCO depending on
		# other kubevirt operators
		rendered=$( \
			${PROJECT_ROOT}/tools/manifest-templator/manifest-templator \
			--namespace=${NAMESPACE} \
			--csv-version=${CSV_VERSION} \
			--container-prefix=${CONTAINER_PREFIX} \
			--container-tag=${CONTAINER_TAG} \
			--image-pull-policy=${IMAGE_PULL_POLICY} \
			--input-file=${infile} \
		)
	fi

	# only write to disk if there is something to write
	if [[ ! -z "$rendered" ]]; then
		out_dir="$(dirname ${DEPLOY_DIR}/${template})"
		out_dir=${out_dir/VERSION/$CSV_VERSION}
		mkdir -p ${out_dir}
		out_file="${out_dir}/$(basename -s .in $template)"
		out_file=${out_file/VERSION/$CSV_VERSION}

		echo -e "$rendered" > $out_file
		if [[ $infile =~ .*crd.yaml.in ]]; then
			# if we have a CRD put it in the olm-catalog
			csv_out_dir="${DEPLOY_DIR}/${CSV_DIR}"
			mkdir -p ${csv_out_dir}
			csv_out_file="${csv_out_dir}/$(basename -s .in $template)"

			echo -e "$rendered" > $csv_out_file
		fi
	fi

done

(cd ${PROJECT_ROOT}/tools/manifest-templator/ && go clean)
