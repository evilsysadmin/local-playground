helm-deps:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add stable https://charts.helm.sh/stable
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update

setup-local-names:
	scripts/setup-local-names.sh

ingress:
	kubectl apply -f yaml/nginx-ingress
	echo "Waiting for ingress controller to fully deploy..." 
	kubectl wait --namespace ingress-nginx \
	--for=condition=ready pod \
	--selector=app.kubernetes.io/component=controller \
	--timeout=240s

observability: helm-deps setup-local-names
	kubectl apply -f monitoring/namespace.yaml
	
	helm upgrade kind-prometheus --install --values monitoring/prometheus-stack-values.yaml \
		prometheus-community/kube-prometheus-stack \
		--namespace monitoring --set prometheus.service.nodePort=30000 \
		--set prometheus.service.type=NodePort \
		--set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
		--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
		--set grafana.service.type=ClusterIP --set alertmanager.service.nodePort=32000 \
		--set alertmanager.service.type=NodePort --set prometheus-node-exporter.service.nodePort=32001 \
		--set prometheus-node-exporter.service.type=NodePort 

	helm upgrade loki-distributed grafana/loki-distributed  --namespace monitoring --install
	
	helm upgrade promtail -f monitoring/promtail.yaml grafana/promtail --install --set "loki.serviceName=loki-distributed-gateway" --namespace monitoring 
	
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
	
	kubectl patch -n kube-system deployment metrics-server --type=json \
  		-p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'


bootstrap:
	bash scripts/kind-with-registry.sh
	$(MAKE) observability
	$(MAKE) ingress	
	$(MAKE) setup-local-names
	
clean:
	kind delete cluster --name local-cluster

