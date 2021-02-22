PROJECT_ID=xxxx
REGION=us-central1
CLUSTER_NAME=istio-demo
GCLOUD_USER=k8s-runner
ISTIO_VERSION=1.9
GCLOUD_EMAIL=$(GCLOUD_USER)@$(PROJECT_ID).iam.gserviceaccount.com

download-istio:
	wget https://github.com/istio/istio/releases/download/$(ISTIO_VERSION)/istio-$(ISTIO_VERSION)-linux.tar.gz
	tar -zxvf istio-$(ISTIO_VERSION)-linux.tar.gz
genereate-istio-template:
	helm template istio-$(ISTIO_VERSION)/install/kubernetes/helm/istio --name istio --namespace istio-system --set global.mtls.enabled=true --set tracing.enabled=true --set servicegraph.enabled=true --set grafana.enabled=true > istio.yaml
create-sa:
	gcloud iam service-accounts create $(GCLOUD_USER) --display-name $(GCLOUD_USER) --project $(PROJECT_ID)
	gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:$(GCLOUD_EMAIL) --role roles/editor --project $(PROJECT_ID)
create-cluster:
	gcloud container --project $(PROJECT_ID) clusters create $(CLUSTER_NAME) --region $(REGION) --no-enable-basic-auth --cluster-version "1.18.12-gke.1210" --release-channel "regular" --machine-type "e2-medium" --image-type "COS" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --service-account $(GCLOUD_EMAIL) --num-nodes "1" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/$(PROJECT_ID)/global/networks/default" --subnetwork "projects/$(PROJECT_ID)/regions/us-central1/subnetworks/default" --default-max-pods-per-node "110" --enable-autoscaling --min-nodes "1" --max-nodes "12" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --workload-pool "$(PROJECT_ID).svc.id.goog" --enable-shielded-nodes --node-locations "us-central1-a","us-central1-b","us-central1-c","us-central1-f"
	kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(GCLOUD_EMAIL)
get-credentials:
	gcloud container clusters get-credentials $(CLUSTER_NAME) --project $(PROJECT_ID) --region $(REGION)
delete-cluster:
	gcloud container clusters delete $(CLUSTER_NAME) --project $(PROJECT_ID)
deploy-istio:
	istioctl install --set profile=demo -y
	kubectl label namespace default istio-injection=enabled --overwrite
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/prometheus.yaml
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/grafana.yaml
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/kiali.yaml
