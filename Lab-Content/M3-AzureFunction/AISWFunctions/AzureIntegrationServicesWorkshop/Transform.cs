using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace LiquidMapper
{
    public static class Transform
    {
        [FunctionName("Transform")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {

            ////// Run method content //////

            log.LogInformation("Starting Transform");

            string templateEncoded = req.Query["template"];
            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic data = JsonConvert.DeserializeObject(requestBody);

            templateEncoded ??= data?.template;
            string template = Base64Decode(templateEncoded);

            if (template != null)
            {
                log.LogInformation("Template ok.");
                var transformer = new Transformer(template, false);
                string transformedString = transformer.RenderFromString(requestBody);
                return (ActionResult)new OkObjectResult(transformedString);
            }
            else
            {
                log.LogWarning("Failed transforming, the template was invalid.");
                return new BadRequestObjectResult("Failed transforming, the template was invalid.");
            }
        }


        ////// Base64Decode ////// 

        public static string Base64Decode(string base64EncodedData)
        {
            if (string.IsNullOrWhiteSpace(base64EncodedData))
            {
                return null;
            }
            var base64EncodedBytes = System.Convert.FromBase64String(base64EncodedData);
            return System.Text.Encoding.UTF8.GetString(base64EncodedBytes);
        }

    }
}
