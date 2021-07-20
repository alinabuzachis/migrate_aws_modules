import os
import sys
import json
import requests


module = sys.argv[1]
branch = sys.argv[2]

git_token = os.getenv('GITHUB_TOKEN')
username = os.getenv('USERNAME')

com_repo = "community.aws"
am_repo = "amazon.aws"

pr_title=f'DNM Migrate {module}* modules and tests'

am_description=f"""
Migrate {module}* modules and tests
"""

def list_pull_request(owner_name, repo_name):
    req_url = ''
    exists = True

    git_pulls_api = "https://api.github.com/repos/{0}/{1}/pulls".format(
        owner_name,
        repo_name,
    )
    headers = {
        "Authorization": "token {0}".format(git_token),
        "Content-Type": "application/json"
    }
    
    for _i in range(30):
        response = requests.get(
            git_pulls_api,
            headers=headers
        )
        if response.status_code == 200:
            for req in response.json():
                if pr_title in req['title']:
                    req_url = req['url']
                    return req_url
    return req_url
       

def create_pull_request(owner_name, repo_name, description, head_branch, base_branch):
    result_url = ''

    """Creates the pull request for the head_branch against the base_branch"""
    git_pulls_api = "https://api.github.com/repos/{0}/{1}/pulls".format(
        owner_name,
        repo_name
    )
    headers = {
        "Authorization": "token {0}".format(git_token),
        "Content-Type": "application/json"
    }
    payload = {
        "title": pr_title,
        "body": description,
        "head": head_branch,
        "base": base_branch,
    }
    print(git_pulls_api)

    response = requests.post(
        git_pulls_api,
        headers=headers,
        data=json.dumps(payload)
    )
        
    if response.status_code == 422:
        # PR already exists
        url = list_pull_request(owner_name, repo_name)
        if url:
            response = requests.patch(
                url,
                headers=headers,
                data=json.dumps(payload)) 
            if response.ok:
                print(f"PR successfully patched in {repo_name}!")
                return response.json()['url']
    
    elif not response.ok:
        print("Request Failed: {0}".format(response.text))
        return ''
    else:
        print(f"PR successfully created on {repo_name}!")
        return response.json()['url']


# Create PR inside amazon.aws

req_url = create_pull_request(
    "ansible-collections", # owner_name
    am_repo, # repo_name
    am_description, # description
    f"{username}:{branch}", # head_branch
    "main", # base_branch
)

url = ''
if req_url:
    url = f"https://github.com/ansible-collections/amazon.aws/pull/{req_url.split('/')[-1]}"

com_description=f"""
Depends-On: {url}

Remove {module}* modules and tests
These modules have been migrated to `amazon.aws`
Update runtime.yml with redirects to that collection
Update ignore files
"""

# Create PR inside community.aws
_ = create_pull_request(
    "ansible-collections", # owner_name
    com_repo, # repo_name
    com_description, # description
    f"{username}:{branch}", # head_branch
    "main", # base_branch
)
