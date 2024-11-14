#! /usr/bin/env python
# cython: language_level=3
# distutils: language=c++

""" Create Repo """

import os
from pathlib                                 import Path
import subprocess
from typing                                  import List, Optional, Iterable
from typing                                  import ParamSpec

import dotenv
from git                                     import Repo
from git.exc                                 import InvalidGitRepositoryError
from github                                  import Github
from structlog                               import get_logger

P     :ParamSpec = ParamSpec('P')
logger           = get_logger()

##
#
##

def ensure_local_repo()->Repo:
	try:
		repo:Repo = Repo()
		logger.info('found existing repo: %s', repo,)
		return repo
	except InvalidGitRepositoryError as error:
		logger.error(error)
		repo:Repo = Repo.init()
		logger.info('created new repo: %s', repo,)
		return repo

def get_remote_repo_if_exists(organization, name:str,)->Optional[Repo]:
	for repo in organization.get_repos():
		if (repo.name == name):
			logger.info('found remote repo: %s', repo,)
			return repo
	logger.info('remote repo not found: %s/%s', organization, name,)
	return None

def ensure_remote_repo(token:str, org:str, name:str,)->Repo:
	g:Github = Github(token)
	organization = g.get_organization(org)
	remote_repo:Optional[Repo] = get_remote_repo_if_exists(organization=organization, name=name,)
	if (remote_repo is not None):
		return remote_repo
	assert (remote_repo is None)
	remote_repo:Repo = organization.create_repo(
		name,
		allow_rebase_merge=True,
		auto_init=False,
		#description=description,
		has_issues=True,
		#has_projects=False,
		#has_wiki=False,
		#private=True,
	)
	logger.info('created remote repo: %s', remote_repo,)
	return remote_repo

def ensure_origin(repo:Repo, url:str,):
	if ('origin' in repo.remotes):
		origin = repo.remotes['origin']
		logger.info('origin found: %s', origin,)
		origin.fetch()
		logger.info('origin fetched')
		origin.pull()
		logger.info('origin pulled')
		return origin
	assert ('origin' not in repo.remotes)
	origin = repo.create_remote('origin', url,)
	logger.info('created new origin: %s', origin,)
	return origin

def main()->None:
	assert Path('.env').is_file()
	#dotenv.load_dotenv() # TODO
	dotenv.load_dotenv('.env')
	assert ('GITHUB_TOKEN' in os.environ)

	local_repo:Repo = ensure_local_repo()
	assert (not local_repo.bare)

	token:str = os.environ['GITHUB_TOKEN']
	assert token

	org  :str = os.getenv('GITHUB_ORGANIZATION', 'InnovAnon-Inc')
	assert org
	logger.info('organization: %s', org,)

	name :str = Path().resolve().name
	assert name
	logger.info('repo name   : %s', name,)

	remote_repo:Repo = ensure_remote_repo(token=token, org=org, name=name,)

	message:str = os.getenv('GITHUB_COMMIT_MESSAGE', 'Initial Commit')
	assert message
	logger.info('message     : %s', message,)

	url:str = str(f'https://github.com/{org}/{name}.git')
	assert url
	logger.info('url         : %s', url,)

	local_repo.git.add(all=True,)
	local_repo.index.commit(message,)
	logger.info('committed')

	origin = ensure_origin(repo=local_repo, url=url,)
	assert origin.exists()

	#origin.fetch()
	#logger.info('origin fetched')
	#
	#origin.pull()
	#logger.info('origin pulled')

	origin.push().raise_if_error()
	logger.info('origin pushed')

if __name__ == '__main__':
	main()

__author__:str = 'you.com' # NOQA
