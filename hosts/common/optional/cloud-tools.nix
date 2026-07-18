{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    kubectl
    kubectx
    kubernetes-helm
    opentofu
    awscli2
    azure-cli
    google-cloud-sdk
    doctl
    granted # `assume` — fast multi-account AWS role switching
    aws-sam-cli # local Lambda + API Gateway (sam local invoke / start-api)
    awslogs # tail CloudWatch log groups from the terminal
    localstack # local AWS service emulation (EventBridge/Lambda/API GW)
    steampipe # query live AWS as SQL
  ];
}
