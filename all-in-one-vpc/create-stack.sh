#!/bin/bash
# 
#  Copyright 2017 WSO2, Inc. http://www.wso2.org
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

aws cloudformation create-stack \
--stack-name wso2am-all-in-one-vpc \
--template-body file://WSO2AM210-All-In-One-Deployment-VPC.template.yaml \
--parameters ParameterKey=KeyName,ParameterValue=wso2-key
