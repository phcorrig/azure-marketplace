# Getting Started

Run the following to bring down all the dependencies

```bash
$ npm install
```

# Build

To build the project call

```bash
$ npm run build
```

This will patch the templates according to the configured `build/allowedValues.json` and generate the various data node templates as well as doing several sanity checks and assertions.

The result will be a distribution zip under `dist/elasticsearch-marketplace-DATE.zip` ready to be uploaded to the publisher portal.


## Development

New features should be developed on separate branches and merged back into `master` once complete. To aid in the development process, a gulp task is configured to update all of the github template urls to point at a specific branch so that UI definition and web based deployments can be tested. To run the task

```sh
npm run links
```

will update the links to point to the name of the current branch. Once ready to merge back into `master`, a specific branch name can be passed with

```sh
npm run links -- --branch master
```

If you fork the repository, you can update the links to point to your own github repository using

```sh
npm run links -- --repo <username>/<repo> --branch <branch>
```

where

- `<username>` is your github username and `<repo>` is the name of the Azure Marketplace github repository. Defaults to the remote origin repository.
- `<branch>` is the name of the branch. Defaults to the name of the current branch 

## Test

For this you need to create a [Create a Service Principal - Azure CLI](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/blob/master/docs/get-started/create-service-principal.md).

Then copy the `.test.example.json` file and enter your details

```bash
$ cp build/.test.example.json build/.test.json
```

`.test.json` is git ignored but always take extra care not to commit this file or a copy of it.


```bash
$ npm test
```

Will login to azure create resource group in the form of `test-[scenario]-[date]` and do an online validation of the template using the scenario's parameters.
When done (failures or not) this command will clean up the resource groups and logout of azure.

```bash
$ npm run deploy-all
```

Same as `npm test` but will try and deploy all scenarios expected to be valid once all the scenarios have been validated.
It will do some post install checks on the deployed cluster if it can.

```bash
$ npm run azure-cleanup
```
Will remove all resource-groups starting with `test-*`

## Automated UI tests

The automated ui tests are not (yet) part of the main test command to run them:

```bash
$ npm run headless
```

## Benchmarking

[Rally](https://github.com/elastic/rally) can be deployed onto a separate VM in
conjunction with deploying a cluster, to allow rally benchmarking tracks to
be run against the cluster. An example deployment with PowerShell

```powershell
$location = "Australia Southeast"
# Use the benchmarking branch, which contains the template changes to
# also deploy a benchmarking VM
$templateVersion = "benchmarking"
$templateUrl = "https://raw.githubusercontent.com/elastic/azure-marketplace/$templateVersion/src"
$elasticTemplate = "$templateUrl/mainTemplate.json"
$resourceGroup = "benchmark-premium"
$name = $resourceGroup

$clusterParameters = @{
    "artifactsBaseUrl"= $templateUrl
    "esVersion" = "6.2.4"
    "esClusterName" = $name
    # A single attached disk per data node
    "vmDataDiskCount" = 1
    "vmDataNodeCount" = 3
    "vmSizeDataNodes" = "Standard_DS1_v2"
    "vmSizeMasterNodes" = "Standard_DS1"
    "dataNodesAreMasterEligible" = "Yes"
    "kibana" = "No"
    "storageAccountType" = "Default"
    "benchmark" = "Yes"
    "loadBalancerType" = "external"
    "xpackPlugins" = "Yes"
    "adminUsername" = "russ"
    "authenticationType" = "password"
    "adminPassword" = "Password1234"
    "securityBootstrapPassword" = "Password123"
    "securityAdminPassword" = "Password123"
    "securityReadPassword" = "Password123"
    "securityKibanaPassword" = "Password123"
    "securityLogstashPassword" = "Password123"
    # disable ml, alerting and monitoring X-Pack features
    "esAdditionalYaml" = "xpack.ml.enabled: false\nxpack.monitoring.enabled: false\nxpack.watcher.enabled: false"
}

New-AzureRmResourceGroup -Name $resourceGroup -Location $location
New-AzureRmResourceGroupDeployment -Name $name -ResourceGroupName $resourceGroup `
    -TemplateUri $elasticTemplate -TemplateParameterObject $clusterParameters
```

It's important to deploy a sufficiently powerful benchmark VM with good disk IOPS,
to ensure that rally itself is not a bottleneck in a benchmarking run. The default
SKU size for the benchmarking VM is `Standard_DS4_v2` with 16 Premium managed disks in
RAID 0.

Once the deployment has finished, ssh into the benchmark VM

```sh
ssh <admin>@<benchmark public ip>
```

configure rally for benchmarking

```sh
esrally configure
nano ~/.rally/rally.ini
```

set `root.dir` and `src.root.dir` to use the managed disks, and optionally change
`env.name` to something meaningful

```sh
[system]
env.name = premium-disks

[node]
root.dir = /datadisks/disk1/.rally/benchmarks
src.root.dir = /datadisks/disk1/.rally/benchmarks/src
```

if capturing metrics in Elasticsearch, include these details. For example,
for storing reports in [Elastic's Elasticsearch Service](https://www.elastic.co/cloud/elasticsearch-service)

```sh
[reporting]
datastore.type = elasticsearch
datastore.host = <id>.<location>.aws.found.io
datastore.port = 9243
datastore.secure = True
datastore.user = <username>
datastore.password = <password>
```

and save the configuration file.

Now to run a benchmark; In this example

1. [the `pmc` track is used](https://github.com/elastic/rally-tracks/tree/master/pmc)
which is a reasonable track for benchmarking indexing latency and throughput
2. The addresses to all data nodes are provided
3. Rally is configured to abort when there is a request error

```sh
esrally --pipeline=benchmark-only --target-hosts=data-0:9200,data-1:9200,data-2:9200 \
        --client-options="basic_auth_user:'elastic',basic_auth_password:'Password123',timeout:300" \
        --on-error=abort --track=pmc --challenge=append-no-conflicts-index-only
```

Results can be further annotated by passing user tags on the command line. For example, `--user-tag="storage:local-ssd"`. 

Consult the [command line reference](https://esrally.readthedocs.io/en/latest/command_line_reference.html) for further details.

Once the benchmark has finished, the high level overview will be output to stdout, with more detail captured in Elasticsearch (if configured as a datastore) or in `~/.rally/benchmarks/races`.
