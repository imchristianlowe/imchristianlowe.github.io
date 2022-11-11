---
title: AWS CLI
date: 2022-11-10 00:00:00 +/-TTTT
categories: [Cheatsheets, Command Line Tools]
tags: [aws]     # TAG names should always be lowercase
mermaid: true
toc: true
---

# Temporary Session Creds
```
result=$(aws sts assume-role --role-arn arn:aws:iam::111111111111:role/Administrator --role-session-name "RoleSession1")
export AWS_ACCESS_KEY_ID=$(echo $result | jq '.Credentials.AccessKeyId' -r)
export AWS_SECRET_ACCESS_KEY=$(echo $result | jq '.Credentials.SecretAccessKey' -r)
export AWS_SESSION_TOKEN=$(echo $result | jq '.Credentials.SessionToken' -r)
```