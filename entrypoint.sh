#!/bin/bash
set -eu

GIT_USER_NAME=${1}
GIT_USER_EMAIL=${2}
PACKAGE_MANAGER=${3}
BUMP_VERSION=${4}
PRE_COMMIT_SCRIPT=${5}
PULL_REQUEST_LABELS=${6}
TARGET_VERSION=${7}

npx npm-check-updates -u -t ${TARGET_VERSION}

if [ "${PACKAGE_MANAGER}" == 'npm' ]; then
  npm i --package-lock-only
  npm audit fix --force
elif [ "${PACKAGE_MANAGER}" == 'yarn' ]; then
  yarn install
else
  echo "Invalid package manager '${PACKAGE_MANAGER}'. Please set 'package-manager' to either 'npm' or 'yarn'."
  exit 1
fi

if $(git diff-index --quiet HEAD); then
  echo 'No dependencies needed to be updated!'
  exit 0
fi

if [ -n "${BUMP_VERSION}" ]; then
  if [ "${PACKAGE_MANAGER}" == 'npm' ]; then
    npm version --no-git-tag-version ${BUMP_VERSION}
  elif [ "${PACKAGE_MANAGER}" == 'yarn' ]; then
    yarn version --no-git-tag-version "--${BUMP_VERSION}"
  fi
fi

DESCRIPTION="chore: update deps ($(date -I))"
PR_BRANCH=chore/deps-$(date +%s)

git config user.name ${GIT_USER_NAME}
git config user.email ${GIT_USER_EMAIL}
git checkout -b ${PR_BRANCH}

if [ -n "${PRE_COMMIT_SCRIPT}" ]; then
  ${PRE_COMMIT_SCRIPT}
fi

git commit -am "${DESCRIPTION}"
git push origin ${PR_BRANCH}

RUN_LABEL="${GITHUB_WORKFLOW}@${GITHUB_RUN_NUMBER}"
RUN_ENDPOINT="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

gh pr create \
  --title "${DESCRIPTION}" \
  --body "_Generated by [${RUN_LABEL}](${RUN_ENDPOINT})._" \
  --head "${PR_BRANCH}" \
  --label "${PULL_REQUEST_LABELS}"
