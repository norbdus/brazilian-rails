# encoding: UTF-8
require 'net/http'
require 'rexml/document'

# Este recurso tem como finalidade encontrar um endereço através de um CEP, e
# para isso ele utiliza o web service da Bronze Business (http://www.bronzebusiness.com.br/webservices/wscep.asmx)
# e o web service do Buscar CEP (http://www.buscarcep.com.br). O segundo só é utilizado quando
# o primeiro está indisponível ou quando ele não encontra o endereço associado ao CEP informado.
# Obviamente, para utilizar este serviço é necessário uma conexão com a Internet.
# 
#Como fazer a busca de endereço por cep?
#
# Cep.find(22640100)     ==> ['Avenida', 'das Americas', 'Barra da Tijuca', 'RJ', 'Rio de Janeiro', '22640100']
# Cep.find('22640100')   ==> ['Avenida', 'das Americas', 'Barra da Tijuca', 'RJ', 'Rio de Janeiro', '22640100']
# Cep.find('22640-100')  ==> ['Avenida', 'das Americas', 'Barra da Tijuca', 'RJ', 'Rio de Janeiro', '22640100']
# Cep.find('22.640-100') ==> ['Avenida', 'das Americas', 'Barra da Tijuca', 'RJ', 'Rio de Janeiro', '22640100']
# Cep.find('04006000')   ==> ["Rua", "Doutor Tomaz Carvalhal", "Paraiso", "SP", "Sao Paulo", "04006000"]
#
# É feita uma validação para ver se o cep possui 8 caracteres após a remoção de '.' e '-'.
# Cep.find('0000000')   ==> RuntimeError 'O CEP informado possui um formato inválido.'

class Cep

  #Services
  URL_WEB_SERVICE_BRONZE_BUSINESS = 'http://www.bronzebusiness.com.br/webservices/wscep.asmx/cep?strcep=' #:nodoc:
  URL_WEB_SERVICE_BUSCAR_CEP = 'http://www.buscarcep.com.br/?cep=' #:nodoc:

  # Elementos do XML retornado pelos web services
  ELEMENTOS_XML_BRONZE_BUSINESS = %w(logradouro nome bairro UF cidade) #:nodoc:
  ELEMENTOS_XML_BUSCAR_CEP = %w(tipo_logradouro logradouro bairro uf cidade) #:nodoc:
  
  # Retorna um array com os dados de endereçamento para o cep informado ou um erro quando o serviço está indisponível,
  # quando o cep informado possui um formato inválido ou quando o endereço não foi encontrado.
  #
  # Exemplo:
  #  Cep.find(22640100) ==> ['Avenida', 'das Americas', 'Barra da Tijuca', 'RJ', 'Rio de Janeiro', 22640100]
  def self.find(numero)
    @@cep = numero.to_s.gsub(/\./, '').gsub(/\-/, '')

    #verifica cep inválido
    if @@cep.length != 8
      raise "O CEP informado possui um formato inválido." if BrCep.cep_invalido == :throw   
      return nil if BrCep.cep_invalido == :nil
    end

    @@retorno = []

    begin
      usar_web_service_da_bronze_business
    rescue
      usar_web_service_do_buscar_cep
    end
    
    @@retorno << @@cep
  end

  private
  
  def self.usar_web_service_da_bronze_business
    @@response = Net::HTTP.Proxy(BrCep.proxy_address, BrCep.proxy_port).get_response(URI.parse("#{URL_WEB_SERVICE_BRONZE_BUSINESS}#{@@cep}"))
    raise "A busca de endereço por CEP através do web service da Bronze Business está indisponível." unless @@response.kind_of?(Net::HTTPSuccess)

    @@doc = REXML::Document.new(@@response.body)
    processar_xml ELEMENTOS_XML_BRONZE_BUSINESS
  end

  def self.usar_web_service_do_buscar_cep
    @@response = Net::HTTP.Proxy(BrCep.proxy_address, BrCep.proxy_port).get_response(URI.parse("#{URL_WEB_SERVICE_BUSCAR_CEP}#{@@cep}&formato=xml"))
    raise "A busca de endereço por CEP está indisponível no momento." unless @@response.kind_of?(Net::HTTPSuccess)
    
    @@doc = REXML::Document.new(@@response.body)
    processar_xml ELEMENTOS_XML_BUSCAR_CEP
  end

  def self.processar_xml(elementos_do_xml)
    elementos_do_xml.each do |e|
      elemento = REXML::XPath.match(@@doc, "//#{e}").first

      raise "CEP #{@@cep} não encontrado." if elemento.nil?

      # Remove os acentos já que o Buscar Cep retorna o endereço com acento e a Bronze Business não
      @@retorno << elemento.text
    end
  end
end

