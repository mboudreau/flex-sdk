
package mx.automation.tabularData
{ 
	
	import mx.automation.AutomationManager;
	import mx.automation.IAutomationObject;
	import mx.automation.IAutomationTabularData;
	import mx.collections.CursorBookmark;
	import mx.collections.errors.ItemPendingError;
	import mx.controls.listClasses.IListItemRenderer;
	import mx.controls.List;
	import mx.core.mx_internal;
	use namespace mx_internal;
	
	/**
	 *  @private
	 */
	public class ListTabularData extends ListBaseTabularData
	{
		
		private var list:List;
		
		/**
		 *  Constructor
		 *  
		 *  @langversion 3.0
		 *  @playerversion Flash 9
		 *  @playerversion AIR 1.1
		 *  @productversion Flex 3
		 */
		public function ListTabularData(l:List)
		{
			super(l);
			
			list = l;
		}
		
		/**
		 *  @inheritDoc
		 *  
		 *  @langversion 3.0
		 *  @playerversion Flash 9
		 *  @playerversion AIR 1.1
		 *  @productversion Flex 3
		 */
		override public function getAutomationValueForData(data:Object):Array
		{
			var item:IListItemRenderer = list.getListVisibleData()[list.getItemUID(data)];
			
			if (item == null)
			{
				item = list.getMeasuringRenderer(data);
				list.setupRendererFromData(item, data);
			}
			
			var delegate:IAutomationObject = (item as IAutomationObject);
			return [ delegate.automationValue.join(" | ") ];
		}
	}
}
