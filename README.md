Kanboard
========

Subject
========
We want you to containerize kanboard: https://github.com/kanboard/kanboard.
Imagine that we want to have a generic container to deploy on production along
other services/containers. It does not need to handle SSL/TLS, this would be done at an upper level.

Someone that uses your project should be able to administer it without your help.
Any custom container should be using/deriving from debian buster (or
buster-slim).

If you decide to use only one container for all services, you'll need to use a
service manager.

You can take the time you want (in the limit of 3 days) but tell us how much time
it took you and what difficulties you encountered or why you made certain choices.

Bonus points for :

providing a kubernetes manifest for the deployment
implementing some of the best practices about the previous point
producing lightweight image(s)/container(s)
having a build pipeline

Results
========
### Dockerfile
The Dockerfile I made is located here `Dockerfile/Dockerfile.buster` with the original Dockerfile provided by the kanboard project.
As the subject told me to dockerised the application, I choose not to update any original files. It may add overhead during the build of the image but also add the possibility to choose between `alpine` or `buster` images.

### docker-compose
I imagined a developer which try to test its application, so I created a docker-compose located at the root of the repository. This docker-compose build the image each time someone launch it with `docker-compose up --build`. It cause a additional time before the test, with the play of layers and cache in docker this additional time remains small.
In production the kanboard project will be launch with a database (easier to backup, manage, mutualisation, ...), in my project postgresql. So I add a postgresql database on the docker-compose.

>
### Kubernetes
In order to deploy kanboard on kubernetes, I made a little kustomize, located on the directory `k8s/bases/kustomization.yaml`
This project will link and kustomize :
* deployment.yaml : kind StatefulSet because it's easier to manage when we are dealing with pv/pvc
* service.yaml : simple service in order to join kanboard pods
* config/config.php: the config file of kanboard
* (optional) ingress/ingress.yaml: I used to work with nginx, so I created an ingress file working with nginx
* (optional) ingress/letsencrypt.yaml: The ingress is directly link to cert-manager and letsencrypt (free and useful)
> The optional parts can be deleted by commenting the line k8s/kustomization.yaml:10 (`- ./ingress # Comment this line to delete ingress and tls certificate`)

I assumed that a postgresql would already be on the kubernetes cluster, In order to deploy one and create the secret which is required by the kanboard deployment, you need to use the little script `k8s/postgresql/secret.sh` by using the folowing command `./secret.sh <namespace>` (should be the same namespace fill in the kustomize `k8s/bases/kustomization.yaml`).
> The script will install bitnami-labs/sealed-secrets, in order to cypher the secret. It allows devops to push secret on git without any worries.

### Pipeline
The buster image is build every push on main thnaks to github action `.github/workflows/ci.yaml`. Yhis workflow will build the image, push it on dockerhub (with the short hash of the commit) then update the kustomize.
> I usely scan my code with sonarcloud and my docker container with harbor/trivy but I didn't had these tols with me for this exercise

The update is very usefull for gitops. I choose `argocd` which is synked with github and deploy my application on every push on main.
Here is the yaml manifest to configure the gitops part:
```Yaml
# k8s/argocd.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kanboard
  namespace: argocd
spec:
  destination:
    namespace: kanboard
    server: https://kubernetes.default.svc
  project: default
  source:
    path: k8s/bases
    repoURL: https://github.com/quentinalbertone/kanboard
    targetRevision: HEAD
  syncPolicy:
    automated: {}
    syncOptions:
    - CreateNamespace=true
```
> Life is simplier with automated deployment
