#coding: utf-8

class TimeDimensionGenerator
    attr_accessor :dimension_class

    def generate
      0.upto(23) do |t|
        0.upto(59) do |m|
          p = {
            descricao: "#{'%02d' % t}:#{'%02d' % m}",
            hora: t,
            minuto: m,
            madrugada: ((t >= 0) and (t < 6)),
            manha: ((t >= 6) and (t < 12)),
            tarde: ((t >= 12) and (t < 18)),
            noite: ((t >= 18) and (t <= 23)),
            horario_de_almoco: ((t >= 12) and (t < 14)),
          }
          td = Datawarehouse::TimeDimension.find_by_hora_and_minuto(t,m)
          if td
            td.update_attributes(p)
            td.save
          else
            Datawarehouse::TimeDimension.create(p)
          end
          puts "Generated #{p[:descricao]}"
        end
      end
    end

end
