using System;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.Functions.Worker.Http;

namespace testing
{
    public class ReadQueueFunction
    {
        private readonly ILogger<ReadQueueFunction> _logger;
        // Set your queue name here
        private readonly string _queueName = "outqueue";

        // Set your storage account URI here
        private readonly string _storageAccountUri = $"https://{Environment.GetEnvironmentVariable("SharedStorageAccount__accountName")}.queue.core.windows.net";

        // Set the client ID of your user-assigned identity
        private readonly string _userAssignedClientId = $"{Environment.GetEnvironmentVariable("SharedStorageAccount__clientId")}";

        public ReadQueueFunction(ILogger<ReadQueueFunction> logger)
        {
            _logger = logger;
        }

        [Function("ReadQueueFunction")]
        public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequestData req)
        {
            _logger.LogInformation("C# HTTP trigger function processing a request.");

            var response = req.CreateResponse(System.Net.HttpStatusCode.OK);

            if (req.Method == "GET")
            {
                try
                {
                    // Use DefaultAzureCredential with the client ID for the user-assigned identity
                    var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
                    {
                        ManagedIdentityClientId = _userAssignedClientId
                    });

                    // Create a QueueClient using the user-assigned identity
                    var queueClient = new QueueClient(new Uri($"{_storageAccountUri}/{_queueName}"), credential);

                    // Receive the next message in the queue
                    var message = await queueClient.ReceiveMessageAsync();

                    if (message.Value != null)
                    {
                        // Process message content
                        string messageContent = message.Value.MessageText;

                        try
                        {
                            // Attempt to decode the message assuming it's Base64
                            byte[] decodedBytes = Convert.FromBase64String(messageContent);
                            string decodedMessage = System.Text.Encoding.UTF8.GetString(decodedBytes);

                            // Log the decoded message (check if it's readable)
                            _logger.LogInformation("Received decoded message: {Message}", decodedMessage);

                            // If it's not a valid Base64 encoding, use the original message
                            if (decodedMessage.Contains("�"))  // UTF-8 invalid character indicator
                            {
                                _logger.LogWarning("Message could not be decoded as Base64. Using raw message.");
                                decodedMessage = messageContent;
                            }

                            // Delete the message after reading
                            await queueClient.DeleteMessageAsync(message.Value.MessageId, message.Value.PopReceipt);

                            await response.WriteStringAsync($"Message: {decodedMessage}");
                        }
                        catch (FormatException)
                        {
                            // If it's not Base64, fall back to the original message
                            _logger.LogWarning("Message is not Base64 encoded, using raw message.");
                            await response.WriteStringAsync($"Message: {messageContent}");
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Error processing message.");
                            await response.WriteStringAsync("Error processing message content.");
                        }
                    }
                    else
                    {
                        await response.WriteStringAsync("Queue is empty.");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error reading message from queue.");
                    response = req.CreateResponse(System.Net.HttpStatusCode.InternalServerError);
                    await response.WriteStringAsync("Error reading message from queue.");
                }
            }
            else
            {
                await response.WriteStringAsync("Welcome to Azure Functions!");
            }

            return response;
        }
    }
}
