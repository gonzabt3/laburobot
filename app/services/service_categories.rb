# Service catalog: canonical service categories for LaburoBot in Argentina
module ServiceCategories
  CATALOG = {
    "plomeria"        => %w[plomero plomeria cañeria agua grifo],
    "electricidad"    => %w[electricista electricidad luz corriente],
    "albanileria"     => %w[albanil albanileria construccion refaccion],
    "pintura"         => %w[pintor pintura pared],
    "jardineria"      => %w[jardinero jardineria pasto cesped plantas],
    "limpieza"        => %w[limpieza empleada mucama aseo],
    "mudanza"         => %w[mudanza flete transporte camion],
    "gasfiteria"      => %w[gasfiter gas calefon calefaccion estufa],
    "cerrajeria"      => %w[cerrajero cerradura llave puerta],
    "carpinteria"     => %w[carpintero carpinteria madera mueble],
    "refrigeracion"   => %w[aire acondicionado refrigeracion heladera],
    "electrodomesticos" => %w[electrodomestico lavarropas lavadora secadora],
    "informatica"     => %w[computadora pc laptop reparacion software],
    "cuidado_personal" => %w[peluquero peluqueria barbero manicura],
    "cuidado_ninos"   => %w[niñera babysitter cuidado ninos],
    "cuidado_ancianos" => %w[enfermero cuidado ancianos adultos],
    "cuidado_mascotas" => %w[veterinario mascota perro gato paseador],
    "clases"          => %w[profesor clase clases matematica ingles],
    "otro"            => []
  }.freeze

  ALL_KEYS = CATALOG.keys.freeze
end
