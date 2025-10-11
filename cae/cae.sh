#!/usr/bin/bash

# Description
#   Checks the current installment of the CAE loan.
#   A new installment is released between the 5th and the 8th of each month.
#
# Usage
#   cae.sh [DNI]
#
# OS: Linu Arch 6.14

# Functions
# -----------------------------------------------------------------------------
#<
# $1: command
# $2: packages gestor
function install_if_not_exists {
    if [[ -z $(command -v "${1}") ]]; then
        echo "Installing '${1}'..."
        sudo $2 -S $1
    fi
}

# $1: dni
function is_dni_format_valid {
#<
    [[ $1 =~ ^[0-9]{1,2}\.?[0-9]{3}\.?[0-9]{3}-?[0-9kK]$ ]]
#>
}
# $1: dni
function is_dni_len_valid {
#<
    # Clean first
    dni=${1//.-/}
    dnilen=${#dni}
    [[ $dnilen -ge 8 && $dnilen -le 9 ]]
#>
}

# $1: dni
function is_dni_valid {
#<
    # Algorithm: modula 11

    # Clean first
    dni=${1//[.-]/}

    # Extracts the verificator digit
    vd=${dni: -1};

    _dni=${dni:0:-1}
    _dni_reversed=$(str_reverse $_dni)
    dnilen=${#_dni}

    m=2 # Incremental factor 2-7
    s=0 # Acumulator

    # Calculate verificator digit
    for (( i=0; i<dnilen; i++ )); do
        d=${_dni_reversed:$i:1}
        s=$((s + (d * m)))
        [[ $m -lt 7 ]] && m=$((m + 1)) || m=2
    done
    # Calculated verificator digit
    cvd=$((11 - (s % 11)))

    # Final veritications
    if [[ $cvd -ge 0 && $cvd -le 10 ]]; then
        [[ $vd -eq $cvd ]]
    elif [[ $cvd -eq 10 ]]; then
        [[ $vd == "k" || $vd == 'K' ]]
    elif [[ $cvd -eq 1 ]]; then
        [[ $vd -eq 0 ]]
    fi
#>
}

# $1: str to be reversed
function str_reverse {
#<
    s=$1
    slen=${#1}
    sreversed=""

    for (( i=slen-1; i>=0; i-- )); do
        c=${s:$i:1}
        sreversed=${sreversed}${c}
    done
    echo $sreversed
#>
}
#>

# $1: dni
function get_current_installment {
#<
    dni=${1//.-/}
    URL=$(echo "aHR0cHM6Ly9hcHBzZXJ2dHJ4LnNjb3RpYWJhbmsuY2wvYm90b25wYWdvL2NyZWRpdG8vZ2V0Q3VvdGFz" | base64 -d)
    data="{\"rut\": \"${dni}\", \"codTipoCredito\": \"CAE\"}"

    # Make the POST request
    res=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$data" "$URL")
    #res=$(cat data.json)200
    # Process response
    reslen=${#res}
    _cutat=$((reslen - 3))

    # Extracts the HTTP code and the response
    res_code=${res: -3}
    res=${res:0:$_cutat}

    # Error
    if [[ $res_code -ne 200 ]]; then
        echo "[Error] Can't get the info!"; exit 1;
    # HTTP 200 was received
    else
        rcode=$(echo $res | jq '.code')
        rstatus=$(echo $res | jq '.message' | tr -d '"')

        # Can't get the installment
        if [[ $rcode -eq 1 ]]; then
            echo "[Info] $rstatus"
            exit 0
        fi

        # Read some error
        if [[ $rstatus != 'SUCCESS' ]]; then
            echo "[Error] $rstatus"
            exit 1
        # Read success
        else
            #<
            output=""
            rclient_name=$(echo $res | jq '.result.nombreCliente' | tr -d '"')
            rinstallments=$(echo $res | jq '.result.cuotas | length')

            output="Rut Consultado: $dni\nCliente: $rclient_name\n\nCuotas del crédito\n\n"

            # Get installment info
            for (( i=0; i<rinstallments; i++ )); do
                rinstallment_number=$(echo $res | jq ".result.cuotas[$i].nroCuota" | tr -d '"')
                rinstallment_due_date=$(echo $res | jq ".result.cuotas[$i].fechaVencimiento" | tr -d '"')
                rloan_number=$(echo $res | jq ".result.cuotas[$i].nroCuenta" | tr -d '"')
                ris_installment_delinquent=$(echo $res | jq ".result.cuotas[$i].moroso" | tr -d '"')
                rinstallment_amount=$(echo $res | jq ".result.cuotas[$i].totalCuota" | tr -d '"')
                rlate_fee=$(echo $res | jq ".result.cuotas[$i].interesMora" | tr -d '"')
                rpenalty_interest=$(echo $res | jq ".result.cuotas[$i].reajusteMore" | tr -d '"')
                rinstallment_adjustment=$(echo $res | jq ".result.cuotas[$i].reajuste" | tr -d '"')
                rinstallment_interest=$(echo $res | jq ".result.cuotas[$i].interes" | tr -d '"')
                rinstallment_net_amount=$(echo $res | jq ".result.cuotas[$i].montoPrincipal" | tr -d '"')
                rinstallment_deductions=$(echo $res | jq ".result.cuotas[$i].deducciones" | tr -d '"')
                rcollection_fee=$(echo $res | jq ".result.cuotas[$i].cobroExtrajudicial" | tr -d '"')

                # Delete null
                rinstallment_amount=${rinstallment_amount/null/}
                rlate_fee=${rlate_fee/null/}
                rpenalty_interest=${rpenalty_interest/null/}
                rinstallment_adjustment=${rinstallment_adjustment/null/}
                rinstallment_interest=${rinstallment_interest/null/}
                rinstallment_net_amount=${rinstallment_net_amount/null/}
                rinstallment_deductions=${rinstallment_deductions/null/}
                rcollection_fee=${rcollection_fee/null/}

                # Delete decimal part
                rinstallment_amount=${rinstallment_amount%.*}
                rlate_fee=${rlate_fee%.*}
                rpenalty_interest=${rpenalty_interest%.*}
                rinstallment_adjustment=${rinstallment_adjustment%.*}
                rinstallment_interest=${rinstallment_interest%.*}
                rinstallment_net_amount=${rinstallment_net_amount%.*}
                rinstallment_deductions=${rinstallment_deductions%.*}
                rcollection_fee=${rcollection_fee%.*}

                # Process vars
                ris_installment_delinquent=$([[ $ris_installment_delinquent == "true" ]] && echo 'Sí' || echo 'No')
                rlate_fee=$([[ ${#rlate_fee} -ne 0 ]] && echo $rlate_fee || echo '0')
                rpenalty_interest=$([[ ${#rpenalty_interest} -ne 0 ]] && echo $rpenalty_interest || echo '0')
                rinstallment_adjustment=$([[ ${#rinstallment_adjustment} -ne 0 ]] && echo $rinstallment_adjustment || echo '0')
                rinstallment_interest=$([[ ${#rinstallment_interest} -ne 0 ]] && echo $rinstallment_interest || echo '0')
                rinstallment_net_amount=$([[ ${#rinstallment_net_amount} -ne 0 ]] && echo $rinstallment_net_amount || echo '0')
                rinstallment_deductions=$([[ ${#rinstallment_deductions} -ne 0 ]] && echo $rinstallment_deductions || echo '0')
                rcollection_fee=$([[ ${#rcollection_fee} -ne 0 ]] && echo $rcollection_fee || echo '0')

                output="${output}Cuota: #${rinstallment_number}\n"
                output="${output}==================================================\n"
                output="${output}Resúmen:\n--------------------------------------------------\n"
                output="${output}Total: \$${rinstallment_amount}\n"
                output="${output}Fecha de vencimiento: ${rinstallment_due_date}\n"
                output="${output}Morosidad: ${ris_installment_delinquent}\n"
                output="${output}Reajuste por mora: \$${rlate_fee}\n"
                output="${output}Monto Neto: \$${rinstallment_net_amount}\n"
                output="${output}Reajuste: \$${rinstallment_adjustment}\n"
                output="${output}Interés: \$${rinstallment_interest}\n"
                output="${output}Deducciones: \$${rinstallment_deductions}\n"
                output="${output}Cobro extrajudicial: \$${rcollection_fee}\n"
            done
            #>

            echo -e $output
        fi
    fi
#>
}
# -----------------------------------------------------------------------------

# Install necessary packages
# -----------------------------------------------------------------------------
install_if_not_exists "jq" "pacman"
install_if_not_exists "curl" "pacman"
install_if_not_exists "base64" "pacman"
install_if_not_exists "tr" "pacman"
# -----------------------------------------------------------------------------

# CLI #1
dni=$1

# CLI parameter validation
[[ -z $dni ]] && echo "[Error] DNI not given!" && exit 1;

# DNI validations
#<
if ! is_dni_format_valid $dni; then
    echo "[Error] Invalid DNI format!" && exit 1
elif ! is_dni_len_valid $dni; then
    echo "[Error] Invalid DNI length!" && exit 1;
elif ! is_dni_valid $dni; then
    echo "[Error] Invalid DNI!" && exit 1;
fi
#>

#
get_current_installment $dni
