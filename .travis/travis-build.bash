#!/bin/bash
# build, test, and publish maven projects on Travis CI

set -o pipefail

declare Pkg=travis-build-spring-update
declare Version=0.2.0

function msg() {
    echo "$Pkg: $*"
}

function err() {
    msg "$*" 1>&2
}

function main() {
    if [[ $TRAVIS_EVENT_TYPE != cron ]]; then
        msg "not updating in non-cron Travis CI build"
        return 0
    fi

    msg "building original project"
    local mvn="./mvnw -B -V -U"
    if ! $mvn package; then
        err "failed to package unaltered source"
        return 1
    fi

    msg "downloading starter project zip"
    local seed_name=spring-rest-seed
    local start_url="http://start.spring.io/starter.zip?type=maven-project&language=java&baseDir=$seed_name&groupId=com.atomist&artifactId=$seed_name&name=$seed_name&description=Seed+for+Spring+Boot+REST+services&packageName=com.atomist.spring&packaging=jar&javaVersion=1.8&generate-project=&style=web&style=actuator"
    local zip=$seed_name.zip
    local target_dir=target
    if ! curl -v -o "$target_dir/$zip" "$start_url"; then
        err "failed to download zip of latest start.spring.io project"
        return 1
    fi

    local seed_dir=$target_dir/$seed_name
    rm -rf "$seed_dir"

    msg "unpacking starter project zip"
    if ! ( cd "$target_dir" && unzip "$zip" ); then
        err "failed to extract project zip"
        return 1
    fi

    msg "updating project"
    local new_file base_name
    for new_file in $(find "$seed_dir" -maxdepth 1 -mindepth 1); do
        base_name=${new_file##*/}
        if [[ -e $base_name ]]; then
            if ! rm -r "$base_name"; then
                err "failed to remove old version of $base_name"
                return 1
            fi
        fi
        if ! cp -r "$new_file" .; then
            err "failed to copy $new_file"
            return 1
        fi
    done
    rm -rf "$seed_dir"{,.zip}

    local dirty
    for diff_opt in "" "--cached"; do
        dirty=$(git diff --shortstat $diff_opt 2> /dev/null)
        if [[ $? -ne 0 ]]; then
            err "failed to determine git diff status"
            return 1
        fi
        if [[ $dirty ]]; then
            break
        fi
    done
    if [[ ! $dirty ]]; then
        msg "no changes detected"
        return 0
    fi

    msg "building modified project"
    if ! $mvn clean package; then
        err "maven clean package of modified project failed"
        return 1
    fi

    local xmllint_cmd='setns m=http://maven.apache.org/POM/4.0.0\ncat /m:project/m:parent/m:version/text()\n'
    local spring_release
    spring_release=$(echo -e "$xmllint_cmd" | xmllint --shell pom.xml | grep -v -E '/ >|----')
    if [[ $? -ne 0 || ! $spring_release ]]; then
        err "failed to determine current Spring Boot release version"
        return 1
    fi
    msg "Spring Boot starter parent version: $spring_release"

    if [[ $TRAVIS_PULL_REQUEST != false ]]; then
        msg "not updating on pull request"
        return 0
    fi

    if ! git config user.email "travis-ci@atomist.com"; then
        err "failed to set git user email"
        return 1
    fi
    if ! git config user.name "Travis CI"; then
        err "failed to set git user name"
        return 1
    fi

    local head_ref branch_ref
    head_ref=$(git rev-parse HEAD)
    if [[ $? -ne 0 || ! $head_ref ]]; then
        err "failed to get HEAD reference"
        return 1
    fi
    branch_ref=$(git rev-parse "$TRAVIS_BRANCH")
    if [[ $? -ne 0 || ! $branch_ref ]]; then
        err "failed to get $TRAVIS_BRANCH reference"
        return 1
    fi
    if [[ $head_ref != $branch_ref ]]; then
        msg "HEAD ref ($head_ref) does not match $TRAVIS_BRANCH ref ($branch_ref), not updating"
        return 0
    fi
    if ! git checkout "$TRAVIS_BRANCH"; then
        err "failed to checkout $TRAVIS_BRANCH"
        return 1
    fi

    if ! git add --all .; then
        err "failed to add modified files to git index"
        return 1
    fi
    if ! git commit -m "Update $seed_name from start.spring.io"; then
        err "failed to commit updates"
        return 1
    fi
    local git_tag=start.spring.io-$spring_release+travis$TRAVIS_BUILD_NUMBER
    if ! git tag "$git_tag" -m "Generated tag from Travis CI build $TRAVIS_BUILD_NUMBER"; then
        err "failed to create git tag: $git_tag"
        return 1
    fi
    local remote=origin
    if [[ $GITHUB_TOKEN ]]; then
        remote=https://$GITHUB_TOKEN:x-oauth-basic@github.com/$TRAVIS_REPO_SLUG.git
    fi

    if [[ $TRAVIS_BRANCH != master ]]; then
        msg "not pushing updates to branch $TRAVIS_BRANCH"
        return 0
    fi

    if ! git push --quiet --follow-tags "$remote" "$TRAVIS_BRANCH" > /dev/null 2>&1; then
        err "failed to push git changes"
        return 1
    fi
}

main "$@" || exit 1
exit 0
