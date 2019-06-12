using System;
using System.Collections.Generic;
using System.Text;
using System.Windows.Forms;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.IdentityManagement;
using Amazon.IdentityManagement.Model;
using Amazon.Auth.AccessControlPolicy;
using System.Net;

namespace TekBackupSetup
{
    partial class frmTekbackup : Form
    {
        public string bucketName = "";
        public string ITGName = "";
        public string key1 = "";
        public string key2 = "";
        public string arn = "";
        public string policyarn = "";
        
        public frmTekbackup()
        {
            InitializeComponent(); 
            
        }

//Button1  - Create Bucket
        private void button1_Click(object sender, EventArgs e)
        {
            bucketName = txtID.Text;
            var client = new AmazonS3Client(Amazon.RegionEndpoint.USEast2);

            txtOutput.Text += "\r\n";
            txtOutput.Text +=  "Creating Bucket: " + bucketName + "\r\n";
            try
            {
                PutBucketRequest putRequest1 = new PutBucketRequest
                {
                    BucketName = bucketName
                };
                PutBucketResponse response1 = client.PutBucket(putRequest1);
                txtOutput.Text += response1.ToString() + "\r\n";
                txtOutput.Text +=  "Bucket Created: arn:aws:s3:::" + bucketName + "\r\n";
                arn = "arn:aws: s3:::" + bucketName;

            }
            catch (AmazonS3Exception amazonS3Exception)
            {
                if (amazonS3Exception.ErrorCode != null &&
                    (amazonS3Exception.ErrorCode.Equals("InvalidAccessKeyId")
                    ||
                    amazonS3Exception.ErrorCode.Equals("InvalidSecurity")))
                {
                    txtOutput.Text += "Check the provided AWS Credentials." + "\r\n";
                    txtOutput.Text += "For service sign up go to http://aws.amazon.com/s3" + "\r\n";
                }
                else
                {
                    txtOutput.Text += "Error Creating Bucket!!!!" + amazonS3Exception.Message + "\r\n";
                    txtOutput.Text += amazonS3Exception.ErrorCode + "\r\n";
                }
            }
            txtOutput.ScrollToCaret();
        }

// Button 2 - Create IAM User
        private void button2_Click(object sender, EventArgs e)
        {
            txtOutput.Text += "Creating IAM User: " + bucketName + "\r\n";
            var iamClient2 = new AmazonIdentityManagementServiceClient();
            try
            {
                var readOnlyUser = iamClient2.CreateUser(new CreateUserRequest
                {
                    UserName = bucketName,
                }).User;
                txtOutput.Text += "IAM USER Created: " + bucketName + "\r\n";  
            }
            catch (EntityAlreadyExistsException ex)
            {
                txtOutput.Text += ex.Message + "\r\n";
                var request = new GetUserRequest()
                {
                    UserName = bucketName
                };
            }
            try
            {
                
                txtOutput.Text += "Creating Access Key" + "\r\n";
                var iamClient1 = new AmazonIdentityManagementServiceClient();
                var accessKey = iamClient1.CreateAccessKey(new CreateAccessKeyRequest
                {
             
                    UserName = bucketName
                }).AccessKey;
                txtOutput.Text += "Access Keys Generated:" + "\r\n";
                txtOutput.Text += accessKey.AccessKeyId + "\r\n";
                key1 = accessKey.AccessKeyId;
                txtOutput.Text += accessKey.SecretAccessKey + "\r\n";
                key2 = accessKey.SecretAccessKey;
            }
            catch (LimitExceededException ex)
            {
                txtOutput.Text += ex.Message;
            }
            txtOutput.ScrollToCaret();
        }

//Button3 - Policy
        private void button3_Click(object sender, EventArgs e)
        {
            txtOutput.Text += "Creating Policy" + "\r\n";
            var client = new AmazonIdentityManagementServiceClient();
            string policyDoc = GenerateUserPolicyDocument(bucketName);
            var request = new CreatePolicyRequest
            {
                PolicyName = bucketName + "Policy",
                PolicyDocument = policyDoc
            };
            try
            {
                var createPolicyResponse = client.CreatePolicy(request);
                txtOutput.Text += "Policy named " + createPolicyResponse.Policy.PolicyName + " Created." + "\r\n";
                policyarn = createPolicyResponse.Policy.Arn;
            }
            catch (EntityAlreadyExistsException)
            {
                txtOutput.Text += "Policy " + bucketName + " already exits." + "\r\n";
            }

            txtOutput.Text += "Attaching policy to User" + "\r\n";
            var attachrequest = new AttachUserPolicyRequest
            {
                UserName = bucketName,
                PolicyArn = policyarn
            };
            try
            {
                var createPolicyResponse = client.AttachUserPolicy(attachrequest);
                txtOutput.Text += "Policy applied" + "\r\n";
            }
            catch (Exception)
            {
                txtOutput.Text += "Attach Failed" + "\r\n";
            }
            txtOutput.ScrollToCaret();
        }
        public static string GenerateUserPolicyDocument(string bucketName)
        {

            string resourcearn = "arn:aws:s3:::" + bucketName + "/*";
            string resourcearn2 = "arn:aws:s3:::" + bucketName;
            var actionGet = new ActionIdentifier("s3:*");
            var actions = new List<ActionIdentifier>();
            actions.Add(actionGet);
            var resource = new Resource(resourcearn);
            var resource2 = new Resource(resourcearn2);
            var resources = new List<Resource>();
            resources.Add(resource);
            resources.Add(resource2);
            var statement = new Amazon.Auth.AccessControlPolicy.Statement(Amazon.Auth.AccessControlPolicy.Statement.StatementEffect.Allow)
            {
                Actions = actions,
                Id = bucketName + "Statmentid",
                Resources = resources

            };
            var statements = new List<Amazon.Auth.AccessControlPolicy.Statement>();
            statements.Add(statement);
            var policy = new Policy
            {
                Id = bucketName + "Policy",
                Version = "2012-10-17",
                Statements = statements
            };
            return policy.ToJson();
        }

//Button 5- ITG
        private void button5_Click(object sender, EventArgs e)
        {
            bucketName = txtID.Text;
            ITGName = txtCompany.Text;         
            string json = "{ \"data\":{\"type\":\"passwords\",\"attributes\":{\"name\":\"TekBackup_Access_Keys\",\"password\":\""+key2+ "\",\"password-category-id\":32755,\"notes\":\"Password is Secret Key.\r\nAccess Key: " + key1+"\r\nARN: "+arn+ "\r\nPolicy ARN: " + policyarn+" \"}}}";
            txtOutput.Text += json;       
            string url = "/organizations/"+ITGName+"/relationships/passwords";
            string results = "";
            using (var client = new WebClient())
            {
                client.Proxy = null;
                client.Headers[HttpRequestHeader.Host] = "api.itglue.com";
                client.Encoding = Encoding.UTF8;                
                client.Headers[HttpRequestHeader.ContentType] = "application/vnd.api+json";
                client.Credentials = null;
                client.Headers.Add("x-api-key","ITG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
                client.BaseAddress = "https://api.itglue.com";
                results = client.UploadString(url, "POST", json);
            }
            txtOutput.Text += results;
        }

//Button 4 - CloudBerry
        private void button4_Click(object sender, EventArgs e)
        {
            var oldpolicy = "";
            txtOutput.Text += "Editing CB Role Policy" + "\r\n";

            var client = new AmazonIdentityManagementServiceClient();
            
            var getcurrentrequest = new GetRolePolicyRequest
            {
                PolicyName = "CloudBerryMBSPolicy",
                RoleName = "CloudBerryMBSRole-6bba62a8-a0da-497c-b296-2fe588c64db4"
                
            };
            try
            {
                var getPolicyResponse = client.GetRolePolicy(getcurrentrequest);
                oldpolicy = System.Net.WebUtility.UrlDecode(getPolicyResponse.PolicyDocument);
               
               
                
                
            }
            catch (NoSuchEntityException)
            {
                txtOutput.Text += "Policy does not exist." + "\r\n";
            }
            var newpolicy = oldpolicy.Remove(oldpolicy.Length - 3,3);

            newpolicy += ",{\"Effect\": \"Allow\",  \"Action\": \"s3:*\", \"Resource\": [  \"arn:aws:s3:::"+ txtID.Text + "\"], \"Condition\": {} }, {\"Effect\": \"Allow\",  \"Action\": \"s3:*\", \"Resource\": [  \"arn:aws:s3:::" + txtID.Text + "/*\"], \"Condition\": {} }  ] }";
         

            var putrolepolicyrequest = new PutRolePolicyRequest
            {
                RoleName = "CloudBerryMBSRole-6bba62a8-a0da-497c-b296-2fe588c64db4",
                PolicyName = "CloudBerryMBSPolicy",
                PolicyDocument = newpolicy
            };

            try
            {
                var putPolicyResponse = client.PutRolePolicy(putrolepolicyrequest);
                txtOutput.Text += "CloudBerry Role Policy Update - Success \r\n";

            }
            catch (NoSuchEntityException)
            {
                txtOutput.Text += "Policy does not exist." + "\r\n";
            }
        }



        private void label2_Click(object sender, EventArgs e)
        {

        }
    }
}
