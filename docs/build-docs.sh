#!/bin/bash

set -eou pipefail

# References:
#  - https://github.com/lcdb/lcdb-wf/blob/master/ci/build-docs.sh
#  - https://docs.travis-ci.com/user/encrypting-files
#  - https://gist.github.com/domenic/ec8b0fc8ab45f39403dd

# ----------------------------------------------------------------------------
#
# Repository-specific configuration
#
# ----------------------------------------------------------------------------

# Note that the keypair needs to be specific to repo, so if ORIGIN changes, the
# keypair (docs/key.enc, and the corresponding public key in the setting of the
# repo) need to be updated.
BRANCH="gh-pages"
ORIGIN="httools_py"
GITHUB_USERNAME="NICHD-BSPC"

# DOCSOURCE is directory containing the Makefile, relative to the directory
# containing this bash script.
DOCSOURCE=`pwd`/docs

# DOCHTML is where sphinx is configured to save the output HTML
DOCHTML=$DOCSOURCE/build/html

# tmpdir to which built docs will be copied
STAGING=/tmp/${GITHUB_USERNAME}-docs

# Build docs only if travis-ci is testing this branch:
BUILD_DOCS_FROM_BRANCH="docs"

# ----------------------------------------------------------------------------
#
# END repository-specific configuration. The code below is generic; to use for
# another repo, edit the above settings.
#
# ----------------------------------------------------------------------------

if [[ $CIRCLE_PROJECT_USERNAME != $GITHUB_USERNAME ]]; then
    # exit if not in lcdb repo
    exit 0
fi

REPO="git@github.com:${GITHUB_USERNAME}/${ORIGIN}.git"

# clone the branch to tmpdir, clean out contents
rm -rf $STAGING
mkdir -p $STAGING

SHA=$(git rev-parse --verify HEAD)
git clone $REPO $STAGING
cd $STAGING
git checkout $BRANCH || git checkout --orphan $BRANCH
rm -r *

# build docs and copy over to tmpdir
cd ${DOCSOURCE}
echo `pwd`
make clean html SPHINXOPTS="-j2" 2>&1 | grep -v "WARNING: nonlocal image URL found:"
cp -r ${DOCHTML}/* $STAGING

# commit and push
cd $STAGING
touch .nojekyll
git add .nojekyll

# committing with no changes results in exit 1, so check for that case first.
if git diff --quiet; then
    echo "No changes to push -- exiting cleanly"
    exit 0
fi

if [[ $CIRCLE_BRANCH != docs ]]; then
    echo "Not pushing docs because not on branch '$BUILD_DOCS_FROM_BRANCH'"
    exit 0
fi


# Add, commit, and push
echo ".*" >> .gitignore
git config user.name "Circle CI build"
git config user.email "${GITHUB_USERNAME}@users.noreply.github.com"
git add -A .
git commit --all -m "Updated docs to commit ${SHA}."
echo "Pushing to $REPO:$BRANCH"
git push $REPO $BRANCH &> /dev/null
