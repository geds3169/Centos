<h1 align="center">Gitlab and Postfix interactive installation/h1>   

##### requirement:  

> Root or sudoer account  
> Network access  
> It is better to have a valid domain name  
> A gmail account and application password  
> Certificates are self-generated, no need to import your own.  
> Make sure you secure your domain name (subdomains): SPF / DMARC for professional people DKIM (The trifecta of email protection).  
> SSH pair key later   

##### Specificity:  

> Allows you to change the SSH port during installation  
> Open the necessary ports for Gitlab and Postfix   

##### Recommendation:    

> If you use a transparent proxy (Pfsense/Opense/Squid (...)) run the following commands in the terminal:  
>     export http_proxy=http://"proxy_ip":"port_number"  
>     export https_proxy=https://"proxy_ip":"port_number"    
>     
>     *Squid uses port 3128*

---------
---------
   
<h1 align="center">Kubernetes and nodes/h1>

##### Material resources:  
 -------------------------------------------------------
|   Server Type |   Server Hostname     |     Specs     |
| ------------- | --------------------- | ------------- |
|     Master    | master01.exemple.com  |4GB Ram, 2vcpus|
|     Worker    | Worker01.exemple.com  |4GB Ram, 2vcpus|
|     Worker    | Worker02.exemple.com  |4GB Ram, 2vcpus|
---------------------------------------------------------

> Root or sudoer account  

##### requirement:  

> Root or sudoer account  
