---
title: Project Design - Serverless Authentication
date: 2022-11-11 00:00:00 +/-TTTT
categories: [Project, Serverless Auth]
tags: [terraform, dynamodb, apigateway, lambda]     # TAG names should always be lowercase
mermaid: true
toc: true
---
Requirements
=
- Users must be able to login from any type of device
- Users must be able to create their own account
    - A user must activate their account before being able to login.
    - Users activate their account by entering an mfa code that's sent to the sign up method they used
- Users must be able to update their information (email, phone, password)
    - Before the updated email or phone are saved, they should be verified
- Users must be able to view all of their active authentication tokens
- Users must be able to delete their own authentication tokens in case they believe they have been compromised
- Passwords and tokens must be securely stored to prevent displaying them in clear text. Additionally tokens must be securely generated.
- Users should be able to delete their own account

- Would be nice to have events for user actions to enable future automation
    - Created
    - Updated
    - Deleted
    - Logged In
    - Logged Out

Flow
======

Sign Up Flow
------
```mermaid
sequenceDiagram
    participant User
    participant Server
    User->>Server: Hi. I'd like to register for your site. Here's some info (phone/email & password)
    Server->>User: Great! I've temporarily saved you to my datastore with id 1. Please confirm within 15 minutes with the code I've sent you
    User->>Server: Here's the code you sent me with the user id
    Server->>User: Thank you. Here's an access and refresh token
```

Auth Flow
-----
```mermaid
sequenceDiagram
    User->>Server: Hi. I have that phone number or email and password I gave you when I signed up
    Server->>User: Hi. Here's a temporary code
    User->>Server: Here's the temporary code
    Server->>User: Here's your auth token and a refresh token
    User->>Server: Here's my refresh token before it expires
    Server->>User: Here's a new auth and refresh token
```

Update phone or email flow
---------
```mermaid
sequenceDiagram
    User->>Server: Hi. I have a new phone or email
    Server->>User: Great. I've temporarily saved it. Please enter the code sent to the new info within 15 minutes
    User->>Server: Here's the temporary code
    Server->>User: Great. I've committed your change
```

ERD
==========
```mermaid
erDiagram
    User ||--o{ Token : has

    User {
        uuid id "Unique id for the user."
        string email "Must be unique"
        bool email_verified "Indicator if the email has been verified."
        string phone "Must be unique"
        bool phone_verified "Indicator if the phone has been verified."
        bytes salt "User password salt."
        bytes password "User password hash."
        string mfa_preference "User preference for MFA notifications."
        int created "Epoch timestamp of when the user was created."
        int last_logged_in "Epoc timestamp of when the user last logged in."
    }
    Token {
        string value "Value of the token"
        string user_id FK "The user_id the token is associated with"
        string type "Type of token. auth or mfa"
        string subtype "if type == auth (jwt | session); else (email | phone | login)"
        string device "Device that generated the token."
        string expiration "Datetime string of when the token expires."
        string created "Date time string of when the token was created."
        int ttl "Epoch timestamp of when to expire the token"
    }
```


Base Endpoints
==============
In all routes, either email or phone number are required. The API is almost a copy paste from the [Djoser](https://djoser.readthedocs.io/en/latest/base_endpoints.html) package.

User Create
-----------


Use this endpoint to register new user.

**Default URL**: ``/users/``

**Note**:
```
re_password is only required if USER_CREATE_PASSWORD_RETYPE is True
```

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `login` <br> *`password` <br> * `re_password` | `201_CREATED` <br> * `email` <br> * `phone` <br><br> `400_BAD_REQUEST`|

User Activate
-------------

Use this endpoint to activate user account. This endpoint is not a URL which
will be directly exposed to your users - you should provide site in your
frontend application (configured by ``ACTIVATION_URL``) which will send ``POST``
request to activate endpoint. ``HTTP_403_FORBIDDEN`` will be raised if user is already
active when calling this endpoint (this will happen if you call it more than once).

**Default URL**: ``/users/activation/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `login` <br> * `token` | `204_NO_CONTENT`<br><br> `400_BAD_REQUEST`<br><br>`403_FORBIDDEN`|

User Resend Activation E-mail or Text
------------------------------

Use this endpoint to re-send the activation e-mail. Note that no e-mail would
be sent if the user is already active or if they don't have a usable password.
Also if the sending of activation e-mails is disabled in settings, this call
will result in ``HTTP_400_BAD_REQUEST``

**Default URL**: ``/users/resend_activation/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `login` | `204_NO_CONTENT`<br><br> `400_BAD_REQUEST`<br><br>`403_FORBIDDEN`|


User
----

Use this endpoint to retrieve/update the authenticated user.

**Default URL**: ``/users/me/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `GET`  | | `200_OK`<br>* `email`<br>* `phone`|
| `PUT`  | * `email` <br> * `phone` | `200_OK`<br><br> `400_BAD_REQUEST`<br><br>`403_FORBIDDEN`|
| `PATCH`  | * `email` <br> * `phone` | `200_OK`<br><br> `400_BAD_REQUEST`<br><br>`403_FORBIDDEN`|

User Delete
-----------

Use this endpoint to delete authenticated user. By default it will simply verify
password provided in ``current_password``, delete the auth token if token
based authentication is used and invoke delete for a given ``User`` instance.

**Default URL**: ``/users/me/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `DELETE`  | * `current_password` | `204_NO_CONTENT`<br><br> `400_BAD_REQUEST`<br><br>`403_FORBIDDEN`|

User Tokens
----

Use this endpoint to retrieve/update the authenticated user.

**Default URL**: ``/users/me/tokens/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `GET`  | | `200_OK`<br>* `device`|


Set Password
------------

Use this endpoint to change user password.

**Default URL**: ``/users/set_password/``

```
re_new_password is only required if `SET_PASSWORD_RETYPE` is `True`
```

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `new_password`<br>* `re_new_password`<br>* `current_password` | `204_NO_CONTENT`<br><br> `400_BAD_REQUEST`|


Reset Password
--------------

Use this endpoint to send email to user with password reset link. You have to
setup ``PASSWORD_RESET_CONFIRM_URL``.

**Default URL**: ``/users/reset_password/``

```
HTTP_204_NO_CONTENT if PASSWORD_RESET_SHOW_EMAIL_NOT_FOUND is False

Otherwise if the value of email/phone does not exist in database
HTTP_400_BAD_REQUEST
```

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `login`<br>| `204_NO_CONTENT`<br><br> `400_BAD_REQUEST`|

Reset Password Confirmation
---------------------------

Use this endpoint to finish reset password process. This endpoint is not a URL
which will be directly exposed to your users - you should provide site in your
frontend application (configured by ``PASSWORD_RESET_CONFIRM_URL``) which
will send ``POST`` request to reset password confirmation endpoint.
``HTTP_400_BAD_REQUEST`` will be raised if the user has logged in or changed password
since the token creation.

**Default URL**: ``/users/reset_password_confirm/``

```
re_new_password is only required if PASSWORD_RESET_CONFIRM_RETYPE is True
```

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `login`<br> `token`<br>* `new_password`<br>* `re_new_password`| `204_NO_CONTENT`<br><br> `400_BAD_REQUEST`|


JWT Endpoints
=============


JWT Create
----------

Use this endpoint to obtain JWT or initial login with MFA.

**Default URL**: ``/jwt/create/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `login`<br>* `password`| `200_OK`<br>* `access_token`<br>* `refresh_token`<br><br>`202_ACCEPTED`<br><br>`401_UNAUTHORIZED` <br>* `non_field_errors`|

JWT Create Verify
----------

Use this endpoint to obtain JWT after intiating login with MFA on and receiving MFA code.

**Default URL**: ``/jwt/create/verify/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `login`<br>* `otp`| `200_OK`<br>* `access_token`<br>* `refresh_token`<br><br>`202_ACCEPTED`<br><br>`401_UNAUTHORIZED` <br>* `non_field_errors`|


JWT Refresh
-----------

Use this endpoint to refresh JWT.

**Default URL**: ``/jwt/refresh/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `refresh_token` | `200_OK`<br>* `access_token`<br>* `refresh_token`<br><br>`401_UNAUTHORIZED` <br>* `non_field_errors`|

JWT Verify
----------

Use this endpoint to verify JWT.

**Default URL**: ``/jwt/verify/``

| Method | Request | Response |
| :---         |     :---      | :--- |
| `POST`  | * `access_token` | `200_OK`<br>* `access_token`<br>* `refresh_token`<br><br>`401_UNAUTHORIZED` <br>* `non_field_errors`|


Access Patterns
===============
Let's look at what access patterns we have from our ERD and API

- Create user by email or phone
- Get user by email
- Get user by phone
- Get user by id
- Update user by id
- Delete user by id
- Create token for user
- Get token
- Get tokens for user
- Delete token(s) (manaul)
- Delete token (time based)

Entity Chart
============

| Entity | PK | SK | GSI1PK | GSI1SK | GSI2PK | GSI2SK | Attributes | 
| :---   |:---|:---| :---   | :---   | :---   | :---   | :---   |
| Token | token#{type}#{subtype}#{value} | user#{user_id} | user#{user_id} | token#{type}#{subtype}#{value} | |  | * ttl<br>* created<br>* expires<br>* device
| User | user#{id} | user#{id} | phone#{phone} | phone#{phone} | email#{email} | email#{email} | * password_hash<br>* password_salt<br>* email_verified<br>* phone_verified<br>* created<br>* last_logged_in |

- Need to verify that the value of a JWT won't exceed the secondary key size limit of Dynamodb which is 1024 bytes according to the [docs](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html#HowItWorks.DataTypes)
>For a simple primary key, the maximum length of the first attribute value (the partition key) is 2048 bytes. \
For a composite primary key, the maximum length of the second attribute value (the sort key) is 1024 bytes.

- Why the crazy token key? We want to prevent collisions as much as possible and our application should always know what type of key and the subtype it's looking for so we can always include the type and subtype in the request. The strings are also small enough that they don't take up too much space so our tokens will still be able to fit within the key size limit of 1024. Please see [Verifying Key Sizes](/posts/project-design-serverless-auth/#verifying-key-sizes) to see the code verifying the key size limits.

UMLs
===================
Let's take a look at how we might create classes to interact with Dynamodb based on our access patterns

Token

User and Token Objects
--------------
```mermaid
classDiagram

    class User{
        +id: str = None
        +email: str = None
        +email_verified: bool = False
        +phone: str = None
        +phone_verified: bool = False
        +password: bytes = None
        +salt: bytes = None
        +last_logged_in: str = None
        +created: str = None
        +mfa_preference: str = None

        +to_json()
        +check_password(raw_password: str) None
    }
    class UserCommand~ABC~{
        +create_user(user_dict: dict) User
        +get_user_by_id(id: str) User
        +get_user_by_email(email: str) User
        +get_user_by_phone(phone: str) User
        +update_user(user: User, update_payload: dict) User
        +delete_user(id: str) dict
    }
```

Tokens
---
```mermaid
classDiagram
    class Token{
        -token_type_map: dict
        -value: str
        +user_id: str
        +type: Literal["oauth"]
        +subtype: Literal["access", "refresh"]
        +device: str = None
        +expiration: str = None
        +created: str = None
        +ttl: int = None

        -__post_init__() None
        +to_json()
        +generate_pk()
    }
```

TokenFactory
------------
Leaning on the [Abstract Factory Pattern](https://refactoring.guru/design-patterns/factory-method/)
[Python Example](https://refactoring.guru/design-patterns/factory-method/python/example#lang-features)

This should also be a Singleton so we consistently access the same private key instance throughout the life of the application.\
[Singleton Pattern](https://refactoring.guru/design-patterns/singleton) \
[Python Example](https://refactoring.guru/design-patterns/singleton/python/example#example-1)

This will live in the Lambda layer and be called by the other Lambda functions.
```mermaid
classDiagram
    class TokenFactory~ABC~{
        +get_tokens_by_user_id(id: str) List~Token~
        +create_token(token_dict: dict) Token
        +get_token(token: Token) Token
        +delete(token: Token) dict
        +validate_token(token: Token)
    }

    class JwtTokenFactory~TokenFactory, PrivateKeyBytes~{
        -private_key_bytes

        +public_key
        
        -set_public_key()
        
        +create_token(token_dict: dict) Token
        +get_token(token: Token) Token
        +delete(token: Token) dict
        +validate_token(token: Token)
        +refresh(refresh_token: str)
    }

    class MfaTokenFactory~TokenFactory~{
        +create_token(token_dict: dict) Token
        +get_token(token: Token) Token
        +delete(token: Token) dict
        +validate_token(token: Token)
    }

    TokenFactory <-- JwtTokenFactory
    TokenFactory <-- MfaTokenFactory
```

Token Strategy
-------
Leaning on the [Strategy Pattern](https://refactoring.guru/design-patterns/strategy) \
[Python Example](https://refactoring.guru/design-patterns/strategy/python/example#lang-features)
```mermaid
classDiagram

    class TokenContext~TokenStrategy~{
        -token_strategy: TokenStrategy

        +do_validation() (success: bool, strategy: str)

    }

    class TokenStrategy~TokenFactory~ {
        -factory: TokenFactory

        +validate(*args, **kwargs)
    }

    class JwtStrategy {
        validate(token)
    }
    class MfaStrategy {
        validate(token)
    }

    TokenStrategy <-- JwtStrategy
    TokenStrategy <-- MfaStrategy
```



Sending OTP with Pinpoint
=========================
```python
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier:  Apache-2.0

import boto3
from botocore.exceptions import ClientError
from generate_ref_id import generate_ref_id

### Some variables that are unlikely to change from request to request. ###

# The AWS Region that you want to use to send the message.
region = "us-east-1"

# The phone number or short code to send the message from.
originationNumber = "+18555550142"

# The project/application ID to use when you send the message.
appId = "7353f53e6885409fa32d07cedexample"

# The number of times the user can unsuccessfully enter the OTP code before it becomes invalid.
allowedAttempts = 3

# Function that sends the OTP as an SMS message.
def send_otp(destinationNumber,codeLength,validityPeriod,brandName,source,language):
    client = boto3.client('pinpoint',region_name=region)
    try:
        response = client.send_otp_message(
            ApplicationId=appId,
            SendOTPMessageRequestParameters={
                'Channel': 'SMS',
                'BrandName': brandName,
                'CodeLength': codeLength,
                'ValidityPeriod': validityPeriod,
                'AllowedAttempts': allowedAttempts,
                'Language': language,
                'OriginationIdentity': originationNumber,
                'DestinationIdentity': destinationNumber,
                'ReferenceId': generate_ref_id(destinationNumber,brandName,source)
            }
        )

    except ClientError as e:
        print(e.response)
    else:
        print(response)

# Send a message to +14255550142 that contains a 6-digit OTP that is valid for 15 minutes. The
# message will include the brand name "ExampleCorp", and the request originated from a part of your
# site or application called "CreateAccount". The US English message template should be used to
# send the message.
send_otp("+14255550142",6,15,"ExampleCorp","CreateAccount","en-US")
```

Validating OTP with Pinpoint
=========================================
```python
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier:  Apache-2.0

import boto3
from botocore.exceptions import ClientError
from generate_ref_id import generate_ref_id

# The AWS Region that you want to use to send the message.
region = "us-east-1"

# The project/application ID to use when you send the message.
appId = "7353f53e6885409fa32d07cedexample"

# Function that verifies the OTP code.
def verify_otp(destinationNumber,otp,brandName,source):
    client = boto3.client('pinpoint',region_name=region)
    try:
        response = client.verify_otp_message(
            ApplicationId=appId,
            VerifyOTPMessageRequestParameters={
                'DestinationIdentity': destinationNumber,
                'ReferenceId': generate_ref_id(destinationNumber,brandName,source),
                'Otp': otp
            }
        )

    except ClientError as e:
        print(e.response)
    else:
        print(response)

# Verify the OTP 012345, which was sent to +14255550142. The brand name ("ExampleCorp") and the
# source name ("CreateAccount") are used to generate the correct reference ID.
verify_otp("+14255550142","012345","ExampleCorp","CreateAccount")
```

Verifying Key Sizes
=========
```python
import hashlib
import os
import sys
import uuid

import boto3
import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import rsa

key = rsa.generate_private_key(
    backend=default_backend(),
    public_exponent=65537,
    key_size=2048
)
application_password = b"application-password"

private_key_bytes = key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.BestAvailableEncryption(b'application-password')
)

public_key = key.public_key().public_bytes(
    serialization.Encoding.OpenSSH,
    serialization.PublicFormat.OpenSSH
)

user_id = uuid.uuid4()
salt = os.urandom(32)
user_password = 'password'
hashed_password = hashlib.pbkdf2_hmac('sha256', user_password.encode('utf-8'), salt, 100000)

user = {
    "id": str(user_id),
    "email": "root@test.com",
    "email_verified": False,
    "phone": "+12408675309",
    "phone_verified": False,
    "password": hashed_password,
    "salt": salt,
    "created": "2022-01-01T00:00:00Z",
    "mfa_preference": "phone",
    "last_logged_in": "2022-01-02T:00:00:00Z",
}

jwt_payload = user.copy()
jwt_payload.pop("password")
jwt_payload.pop("salt")

private_key = serialization.load_pem_private_key(
    private_key_bytes, password=application_password, backend=default_backend()
)

encoded = jwt.encode(jwt_payload, private_key, algorithm="RS256")
print(f"# Encoded JWT: {encoded}")
print(f"# Size of encoded jwt: {sys.getsizeof(encoded)}")

pk = f"token#auth#jwt${encoded}"
print(f"# Size of jwt token key {sys.getsizeof(pk)}")

decoded = jwt.decode(encoded, public_key, algorithms=["RS256"])
print(f"# Decoded jwt: {decoded}")
# Encoded JWT: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjU2ZDBkNGExLTgzMmQtNGMwZS1iZTVhLTc5NWNmY2Q4ZjY4YyIsImVtYWlsIjoicm9vdEB0ZXN0LmNvbSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwicGhvbmUiOiIrMTI0MDg2NzUzMDkiLCJwaG9uZV92ZXJpZmllZCI6ZmFsc2UsImNyZWF0ZWQiOiIyMDIyLTAxLTAxVDAwOjAwOjAwWiIsIm1mYV9wcmVmZXJlbmNlIjoicGhvbmUiLCJsYXN0X2xvZ2dlZF9pbiI6IjIwMjItMDEtMDJUOjAwOjAwOjAwWiJ9.haWwdRezILqb-kS3zyJutUixZtt4dcaA2w5C5RZHXspWywKwXDBJK5DeqbtPE4s-BvFtcasVjzkbJ0QVoH4WIrRJyhUBZhe7mo4SRDan9DMzliDXTiALcCGBH8q5w-lUPkDse3s8ULmjJtDGmtdeanDKKD9DF2ffgB2gA2AKWWYIQx4Ds1IjyYXoLrhPoYpPWvKlSp34Z9ctcO8ojufUxcp6J5vGZAuqPWbliLlT2eogNVgUnWX34y2dp2gjc4MdSAmN386YLFVfqcNMn86q_ryEc39J3EjFwrK7TrbkQLg6hrhtaL_rGqgs9gp0xHZ0apALWX1pkjj4oWbCm8JPEA
# Size of encoded jwt: 745
# Size of jwt token key 767
# Decoded jwt: {'id': '56d0d4a1-832d-4c0e-be5a-795cfcd8f68c', 'email': 'root@test.com', 'email_verified': False, 'phone': '+12408675309', 'phone_verified': False, 'created': '2022-01-01T00:00:00Z', 'mfa_preference': 'phone', 'last_logged_in': '2022-01-02T:00:00:00Z'}
```

Resources
==========
[How To Hash Passwords in Python](https://nitratine.net/blog/post/how-to-hash-passwords-in-python/)

[How to Generate RSA Keys with Python](https://stackoverflow.com/questions/2466401/how-to-generate-ssh-key-pairs-with-python)

[Best Authentication to Use](https://www.pingidentity.com/en/resources/blog/post/ultimate-guide-token-based-authentication.html#:~:text=Token%2Dbased%20authentication%20for%20web,able%20to%20access%20the%20application.)
