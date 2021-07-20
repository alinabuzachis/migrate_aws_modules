#!/usr/bin/env bash
set -euo pipefail


module_to_migrate=ec2_vpc_igw

c_a_path=/Users/alinabuzachis/dev/repo_migration/community.aws
a_a_path=/Users/alinabuzachis/dev/repo_migration/amazon.aws

main_folder_scripts=/Users/alinabuzachis/dev/migrate_aws_modules

export GITHUB_TOKEN="Token "
export USERNAME="username"

cd ${c_a_path}
git checkout -B promote_$module_to_migrate origin/main

# --topo-order to be consistent with git filter-branch behavior
git log --pretty=tformat:%H --topo-order > /tmp/change_sha1.txt

# add an URL pointing on the original commit in the commit message
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter "python3 $main_folder_scripts/rewrite.py"

# remove all the files, except the modules we want to keep
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --prune-empty --index-filter 'git ls-tree -r --name-only --full-tree $GIT_COMMIT | \
  grep -v "^plugins/modules/'$module_to_migrate'*" | \
  grep -v "^tests/integration/targets/'$module_to_migrate'*" | \
  xargs git rm --cached --ignore-unmatch -r -f' -- HEAD

# generate the patch files
git format-patch -10000 promote_$module_to_migrate

# apply the patch files
cd ${a_a_path}
git checkout -B promote_$module_to_migrate origin/main
git am ${c_a_path}/*.patch

./tests/sanity/refresh_ignore_files
git add tests/sanity/*.txt
git commit -m "Update ignore files"

cd ${c_a_path}
git checkout origin/main
git branch -D promote_$module_to_migrate
git checkout -B promote_$module_to_migrate origin/main

git ls-files -i -x "*${module_to_migrate}*" | git update-index --force-remove --stdin
git add -u
git commit -m "Remove modules"

sed -i '' '/'$module_to_migrate'/d' tests/sanity/*.txt
git add tests/sanity/*.txt
git commit -m "Update ignore files" 

python3 $main_folder_scipts/regenerare_runtime.py ${c_a_path} ${a_a_path} $module_to_migrate

cd ${a_a_path}
git add meta/runtime*
git commit -m "Update runtime" meta/runtime*

sed -i '' 's/community.aws.'$module_to_migrate'/amazon.aws.'$module_to_migrate'/g' plugins/modules/$module_to_migrate*
sed -i '' 's/collection_name=community.aws/collection_name=amazon.aws/g' plugins/modules/$module_to_migrate*
git add plugins/modules/$module_to_migrate*
git commit -m "Update FQDN"

git add changelogs/fragments/migrate_$module_to_migrate.yml
git commit -m "Add changelog fragment"
git push origin promote_$module_to_migrate --force

cd ${c_a_path}
git add meta/runtime*
git commit -m "Update runtime"
git add changelogs/fragments/migrate_$module_to_migrate.yml
git commit -m "Add changelog fragment"
git push origin promote_$module_to_migrate --force

sleep 10
python $main_folder_scipts/open_pr.py $module_to_migrate promote_$module_to_migrate