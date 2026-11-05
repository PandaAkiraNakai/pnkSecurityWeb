// JavaScript Document

// ES3: toda petición AJAX lleva el token CSRF de la página en la cabecera X-CSRF-Token.
$.ajaxSetup({ headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') } });

$(document).ready(function(){
   $('.button').click(function(){
     agregaritems($(this).attr('id'));
   });

   $('.elim').click(function(){
      eliminaritems($(this).attr('id'));
    });
    $('.limpiar').click(function(){
      eliminartodo();
    });
 });

function agregaritems(id)
{
	$.ajax({
            type: "POST",
            url: 'carrito.php',
            data: "op=1&iditems="+id,
            success: function(response)
            {
				$('#myModal').modal('show');
            }
       });
}

function eliminaritems(pos)
{
	$.ajax({
            type: "POST",
            url: 'carrito.php',
            data: "op=2&pos="+pos,
            success: function(response)
            {
				location.reload();
            }
       });
}

function eliminartodo()
{
	$.ajax({
            type: "POST",
            url: 'carrito.php',
            data: "op=3",
            success: function(response)
            {
				location.reload();
            }
       });
}