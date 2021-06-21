#! /usr/bin/env bash
set -xe

curl https://get.docker.com | sh

usermod -a -G docker ubuntu
