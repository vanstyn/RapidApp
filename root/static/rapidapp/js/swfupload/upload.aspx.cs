using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using System.IO;
using System.Collections.Generic;

public partial class upload : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
		try
		{
			// Get the data
			HttpPostedFile fileUploaded = Request.Files["Filedata"];

			Response.StatusCode = 200;
			Response.Write("{\"success\":true}");
		}
		catch (Exception ex)
		{
			// If any kind of error occurs return a 500 Internal Server error
			Response.StatusCode = 500;
			Response.Write(ex.Message);
			Response.End();
		}
		finally
		{
			// Clean up
			Response.End();
		}
	
	}
}
