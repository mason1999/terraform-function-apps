using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;

namespace testing
{
    public class MyQueueOutputFunction
    {
        private readonly ILogger<MyQueueOutputFunction> _logger;

        public MyQueueOutputFunction(ILogger<MyQueueOutputFunction> logger)
        {
            _logger = logger;
        }

        [Function("MyQueueOutputFunction")]
        public async Task<OutputResponse> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest req)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");
            switch (req.Method.ToUpper())
            {
                case "GET":
                    return new OutputResponse(new string[] { "You sent a GET request! Welcome to Azure functions!", "a"});

                case "POST":
                    string requestBody;
                    using (var reader = new StreamReader(req.Body))
                    {
                        requestBody = await reader.ReadToEndAsync();
                    }

                    switch (req.Headers["Content-Type"].ToString().ToLower())
                    {
                        case "text/plain":
                            return new OutputResponse(new string[] { $"You sent a POST request with a plain string: {requestBody}", "b"});
                        case "application/json":
                            // deserialize json to the InputData object 
                            InputData? inputData;
                            try
                            {
                                inputData = JsonSerializer.Deserialize<InputData>(requestBody);
                            }
                            catch (JsonException ex)
                            {
                                _logger.LogError($"Error deserializing json: {ex.Message}.");
                                return new OutputResponse(new string[] { "Invalid JSON format", "c"});
                            }

                            if (inputData == null)
                            {
                                return new OutputResponse(new string[] { "Deserialization returned null", "d"});
                            }
                            return new OutputResponse(new string[] { $"You send a POST request with a JSON object. Key: {inputData.Key} and Value: {inputData.Value}", "e"});
                        default:
                            return new OutputResponse(new string[] { "Unsupported Content-Type. Please use 'application/json' or 'text/plain'", "f"});
                    }
                default:
                    return new OutputResponse(new string[] { "Unsupported request method.", "g"});
            }
        }
    }

    // Define the model for input data and output data
    public class InputData
    {
        public string? Key { get; set; }
        public string? Value { get; set; }
    }

    public class  OutputResponse
    {
        [QueueOutput("outqueue", Connection = "SharedStorageAccount")]
        public string[]? Messages { get; set; }
        // Constructor to set Messages
        public OutputResponse(string[] messages)
        {
            Messages = messages;
        }
    }
}
