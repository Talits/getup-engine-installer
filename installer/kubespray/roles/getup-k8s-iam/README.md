# IAM Authenticator K8S

Based in > [aws-iam-authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator) :heavy_check_mark:

The role is a function to create authenticator iam based in AWS's users to your Cluster K8S 

Set some vars, like:

|    Var       |   Function                          |
| -------------|-------------------------------------|         
| config_role (Input) | K8SEdit, K8SAdmin or K8SView |
| Account ID   |  AWS (Input) - 12 Chars             |
| Users        | Users                               |
| certificate  | Kubernetes Internal Certificate     |
| Api Server   | Endpoint Kubernetes                 |


#### Execution:

`
  ansible-playbook -i hosts ansible/playbook/getup-k8s-iam/config.yml
`

---

**Author: Getup Cloud**